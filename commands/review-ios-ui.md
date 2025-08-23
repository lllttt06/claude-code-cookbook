# Command: Review current iOS Simulator UI (One-shot)

> 目的: **現在の iOS Simulator 画面**を、`iOS Operator` と `Design Reviewer` を連携させてワンショットで総合レビューする。  
> 前提: アプリは `flutter run -d ios` で起動中。`ios-simulator` MCP が有効。

## 実行内容（このコマンドがやること）
1. **iOS UI Orchestrator**（サブエージェント）を起動
2. Orchestrator が `iOS Operator` に **スクショ/AX** を取得させる
3. Orchestrator が `Design Reviewer` に **最小差分 + 採点** を出させる
4. **総合レポート**（問題≤5、差分、Hot Reload/Restart、スコア、次アクション）を返す

## 使い方
このコマンドを実行すると、以下のプロンプトを Orchestrator に渡します：

```
現在の iOS Simulator の画面を総合レビューしてください。
- iOS Operator に: get_booted_sim_id → ui_view → ui_describe_all → 主導線3点の要約（各ステップの JSON サマリ付き）
- Design Reviewer に: スクショ/AX を渡して 問題≤5, Flutter最小差分(diff), Hot Reload/Restart 別, ルーブリック採点(A–F) を作成
- 最終的に「iOS UI 総合レビュー（現行シミュレータ画面）」テンプレで Markdown レポートを返す
- 画面操作は不要（静的レビュー）。変化が無い場合の再取得は 2 回まで。
```

## 注意
- 出力ファイルが必要な場合は、`IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR` を設定しておくと便利です。
- デザイントークン（ThemeData/AppColors.*）がある場合は、Design Reviewer がそれに従うよう事前に共有してください。

