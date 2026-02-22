#!/bin/bash

# 継続チェック Stop hook
# 合い言葉がなければ「作業を再開してください」と伝える
#
# 合い言葉は CLAUDE.md で定義されている完了時の決まり文句
# 詳細: ~/.claude/CLAUDE.md の「作業完了報告のルール」を参照

COMPLETION_PHRASE="May the Force be with you."
MAX_BLOCK_COUNT=2
LOCK_DIR="/tmp/claude-stop-hook"

# Stop hook から渡される JSON を読み取り
input_json=$(cat)

# --- ループ防止: カウンタベース ---
# セッション ID を取得（なければ PID ベースでフォールバック）
session_id=$(echo "$input_json" | jq -r '.session_id // empty' 2>/dev/null)
if [ -z "$session_id" ]; then
  session_id="default"
fi

counter_file="${LOCK_DIR}/${session_id}.count"
mkdir -p "$LOCK_DIR" 2>/dev/null

# カウンタを読み取り・インクリメント
if [ -f "$counter_file" ]; then
  count=$(cat "$counter_file" 2>/dev/null || echo "0")
  # 数値でなければリセット
  if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    count=0
  fi
else
  count=0
fi

count=$((count + 1))
echo "$count" > "$counter_file"

# MAX_BLOCK_COUNT 回以上連続で block していたらループと判断して許可
if [ "$count" -gt "$MAX_BLOCK_COUNT" ]; then
  rm -f "$counter_file" 2>/dev/null
  exit 0
fi

# --- transcript 解析 ---
transcript_path=$(echo "$input_json" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # 最後のエントリを取得
  last_entry=$(tail -n 1 "$transcript_path")

  # メッセージテキストを複数の方法で取得（transcript 構造の変化に対応）
  last_message=$(echo "$last_entry" | jq -r '.message.content[0].text // empty' 2>/dev/null || echo "")

  # content が配列の場合、全テキストブロックを結合
  if [ -z "$last_message" ]; then
    last_message=$(echo "$last_entry" | jq -r '[.message.content[]? | select(.type=="text") | .text] | join("\n")' 2>/dev/null || echo "")
  fi

  # フォールバック: JSON 全体を文字列化して検索
  full_entry_text=$(echo "$last_entry" | jq -r 'tostring' 2>/dev/null || echo "$last_entry")

  # エラーフィールド
  error_message=$(echo "$last_entry" | jq -r '.message.error // .error // empty' 2>/dev/null || echo "")

  # --- 合い言葉チェック（最優先） ---
  if echo "$last_message" | grep -qF "$COMPLETION_PHRASE" ||
    echo "$full_entry_text" | grep -qF "$COMPLETION_PHRASE"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi

  # --- エラー・特殊状態のバイパス ---

  # Usage limit
  if echo "$full_entry_text" | grep -qi "usage limit"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi

  # ネットワークエラー
  if echo "$full_entry_text" | grep -qi "network error\|timeout\|connection refused"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi

  # /compact 関連
  if echo "$full_entry_text" | grep -qi "Context low.*Run /compact"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi

  # Stop hook feedback のループパターン（OR 条件に緩和）
  if echo "$full_entry_text" | grep -qi "Stop hook.*feedback\|Stop hook.*block\|作業を再開してください"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi

  # Plan mode 承認済み
  if echo "$full_entry_text" | grep -qi "User approved Claude's plan"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi

  # y/n 確認待ち
  if echo "$full_entry_text" | grep -qi "y/n"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi

  # /spec 関連
  if echo "$last_message" | grep -qi "spec\|spec-driven\|requirements\.md\|design\.md\|tasks\.md"; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi
fi

# 合い言葉がなければ継続を促す（カウンタは維持）
cat <<EOF
{
  "decision": "block",
  "reason": "作業を再開してください。\n  続ける作業がない場合は \`$COMPLETION_PHRASE\` を出力して終了してください。"
}
EOF
