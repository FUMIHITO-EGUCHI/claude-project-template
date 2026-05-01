# <!-- @project:name -->

<!-- @project:description -->

## 技術スタック

<!-- @stack:replace -->
- 言語/ランタイム: TODO
- 主要ライブラリ: TODO
- ビルドツール: TODO
<!-- @stack:end -->

## コマンド

<!-- @stack:replace -->
| コマンド | 用途 |
|---|---|
| `npm run dev` | 開発サーバー |
| `npm run build` | ビルド |
| `npm run typecheck` | 型チェック |
<!-- @stack:end -->

完了報告前は `npm run typecheck` と `npm run build`、必要な手動確認を行う。

## タスク管理（AI handoff）

タスクは **GitHub Issues + Projects v2** で管理する。

- 作業開始時: Issue を選んで `status: in-progress` ラベルを付ける
- 作業中: Issue コメントに逐次追記。本文は objective / scope / checklist のみ編集
- 完了申請: `status: ready-for-close` ラベル + `## Result` / `## Verification` / `## Changed files` を含むコメント
- **close は人間のみ**。AI は close しない
- commit message は `#<issue>` を必須（雑務は `[skip-issue]`）。`commit-msg` hook が強制
- AI 間 handoff は `docs/handoff/README.md` の雛形に従う
- Issue 作成時に `model:` ラベル（`cheap-ok` / `standard` / `strong-required`）を1つ付与。判断材料は `task.yml` の "強いモデルを要する兆候" チェックボックス

詳細は `docs/handoff/README.md` を参照。AI 実行制御（GitHub Actions ルーティング、`model:` ラベル運用、コスト管理）は `docs/handoff/ai-execution.md`。他 PJ に展開する手順は `docs/handoff/bootstrap.md`。運用ルールの根拠は ADR（`docs/decisions/0002-github-operation-sot.md` / `0003-human-acceptance-and-ai-tutor.md`）。

## ディレクトリ構造

<!-- @stack:replace -->
| パス | 役割 |
|---|---|
| `src/` | アプリ本体 |
| `docs/handoff/` | AI handoff（Issue ベース）の運用ガイド |
| `docs/decisions/` | ADR |
<!-- @stack:end -->

## 行動原則

- 3ステップ以上のタスクは、実装前に目的・手順・未確定事項を整理する
- 関連ファイルと既存実装を読まずにコードを書かない
- 変更は小さく保つ
- 不確実な情報は未確認と明示し、公式ドキュメントかソースコードで裏取りする
- Claude の主担当は要件整理、調査、ブラウザデバッグ。大きな実装は Codex へ渡しやすい形に整理する

詳細な path-scoped ルールは `.claude/rules/` を参照。
