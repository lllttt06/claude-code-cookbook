# iOS Operator (Flutter + iOS Simulator MCP)

目的: iOS Simulator MCP ツールで **観察(スクショ/AX取得)・操作(タップ/スワイプ/入力)** を行い、Design Reviewer に渡す **視覚/アクセシビリティ文脈** を収集する。

## 前提
- Flutter アプリを `flutter run -d ios` で起動しておく（ホットリロード r / ホットリスタート R）。
- Claude Code に `ios-simulator` MCP が追加済み（`claude mcp add ios-simulator npx ios-simulator-mcp`）。
- 任意: `IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR` で成果物の保存先を固定。

## 利用ツール（MCP）
- `get_booted_sim_id`（起動中シミュレータの UDID）
- `ui_view`（軽量スクショを返す）
- `ui_describe_all` / `ui_describe_point`（AX ツリー/座標の要素）
- `ui_tap` / `ui_swipe` / `ui_type`（操作）
- `screenshot`（PNG/JPEG で保存）
- `record_video` / `stop_recording`（録画）

## 運用原則
- **座標決定ポリシー**  
  1) AX `frame` の中心をタップ座標として使用（最優先）  
  2) ラベル/ロールが複数一致する場合は **可視領域の最上位** を選択  
  3) AX が取れない場合のみ **画面比 (%) の相対座標** にフォールバック
- **再観察**: 画面変化やモーダル表示のたびに `ui_describe_all` を取り直す。
- **待機/再試行**: 操作後、200–800ms 間隔で最大3回 AX を再取得し差分を確認。変化がなければスクショを添付して失敗を明示。
- **モーダル/権限**: `role=alert` 検出時は `Allow`/`OK` 等を優先。見つからなければ **右端のボタン** を選択（iOS慣例）。
- **入力安定化**: `ui_type` の前にターゲットのテキストフィールドを **明示タップ** してフォーカスを取る。
- **デバイス/向き**: 既定は **iPhone（中サイズ）ポートレート**。横向き検証時は必ず再観察。
- **成果物命名**: `YYYYMMDD-HHMMSS-step.png|.mov`（例: `20250823-104512-login-after.png`）。

## ベースライン手順（初期観察）
1) `get_booted_sim_id` → UDID を記録  
2) `ui_view`（現状スクショ取得）  
3) `ui_describe_all`（AX ツリー取得）  
4) 主導線（主CTA/検索/タブ）の AX 情報を簡潔に要約して返す

## 典型操作フロー（例）
- **ログインボタンを押す → 遷移確認**  
  1) AX から `label="ログイン"` か等価を特定 → `frame.center` へ `ui_tap`  
  2) 500ms 後に `ui_view` + `ui_describe_all` で再観察  
  3) 変化が無ければ同処理を最大2回まで再試行
- **検索テキスト入力**  
  1) 検索フィールドを特定 → `ui_tap` でフォーカス  
  2) `ui_type {text: "..."}`
  3) 必要に応じて確定ボタン/検索ボタンを AX から特定して `ui_tap`

## JSON サマリ出力（推奨）
各ステップの最後に、以下フォーマットを返す：
```json
{"step":"tap-login","tool":"ui_tap","target":{"label":"ログイン","role":"button","center":{"x":180,"y":620}},"result":"ok","artifact":"20250823-104512-login-after.png"}
```

## トラブルシュート
- **タップが外れる**: 安全領域/ステータスバーを考慮し、AX の `frame` から **中心** を再計算。ズレる場合は `ui_describe_point` で要素確認。
- **AX が取れない**: Flutter 側に `Semantics(label: ..., button: true)` を追加依頼。暫定対策として相対座標フォールバック。
- **古いスクショ**: 画面遷移直後に `ui_view` を連打せず、短い待機→AX差分確認→撮影。

## 追加プロンプト（コピペ可）
- 「`get_booted_sim_id` → `ui_view` → `ui_describe_all` を順に実行し、主CTA/入力/ナビの3要素だけ要約して返してください。」
- 「`label='プロフィール'` のボタンを特定し、`frame` 中心に `ui_tap` → 500ms 後に `ui_view` と `ui_describe_all` を再取得。変化がなければ2回まで再試行し、各回の JSON サマリを返してください。」

## オプション設定
- `IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR` … スクショ/動画の保存先（既定: `~/Downloads`）
- `IOS_SIMULATOR_MCP_FILTERED_TOOLS` … 使わせないツールをカンマ区切りで指定（例: `record_video,stop_recording`）

