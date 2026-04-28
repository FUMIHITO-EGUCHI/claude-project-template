# AGENTS.md

## Project

<!-- @project:description -->

## Goal

<!-- @stack:replace -->
TODO: 何を達成するためのプロジェクトか。3〜6 行で。
<!-- @stack:end -->

## Product Direction

<!-- @stack:replace -->
重視する点 / 重視しない点を 3〜5 個ずつ。
<!-- @stack:end -->

## Architecture Direction

<!-- @stack:replace -->
- 言語/ランタイム: TODO
- 主要ライブラリ: TODO
- データストア: TODO
<!-- @stack:end -->

## Working Rules

- 大きな変更に入る前に、現状確認、要件整理、データモデル整理、画面責務整理、実装ステップ分解を行う
- 実装は小さな単位に分け、曖昧なことは推測で埋め切らず未確定事項として残す
- feature branch 前提で作業し、開始前に `git status` と `git branch --show-current` を確認する
- `git push` はユーザーから明示的な指示がある場合にのみ行う
- 実装変更時は少なくとも `npm run typecheck`、`npm run build`、影響した処理の動作確認を行う

## Shell Encoding Rules (Windows)

- Windows で日本語を含む入出力を扱うときは、可能な限り PowerShell 7 (`pwsh`) を優先する
- `Get-Content` を使うなら `-Encoding UTF8` を明示するか、PowerShell 7 上で実行する
- 書き込みは UTF-8 no-BOM を明示し、PowerShell 5.1 の既定書き込みに依存しない
- 日本語を heredoc / stdin 経由で外部コマンドに流さない。UTF-8 ファイルか JSON body を使う
- 文字化けして見えたら、修復前に `Format-Hex`、Node、.NET など UTF-8 を明示できる経路で実体確認する

## AI Collaboration

- Claude の主担当は計画立案、要件整理、調査、デバッグ、切り分け
- Codex の主担当は実装、リファクタ、テスト、レビュー、ドキュメント作成、Git 関連作業
- Claude から Codex へ渡す調査結果は、生ログではなく圧縮した結論・根拠・未解決点だけにする
- handoff 前には Goal、In scope、Out of scope、Constraints、Compressed findings、Files to read first、Acceptance criteria、Open questions が分かる状態を目指す
- タスク管理は **GitHub Issues + Projects v2** を single source of truth とする
- Issue 作成は Claude / Codex / human いずれも可。テンプレ（Task / Investigation / Bug）→ 初期ラベル `status: todo` + `owner:` + `priority:` + `type:` + `area:`。他 AI に投げる場合は `owner: <相手>` で止める
- 作業中は Issue コメントに逐次追記（本文は objective / scope / checklist のみ編集）。完了申請は `status: ready-for-close` + `## Result` / `## Verification` / `## Changed files` コメント。close は人間のみ
- commit message に `#<issue>` 必須（雑務は `[skip-issue]`）。`commit-msg` hook が強制
- Issue 作成時に `model:` ラベル（`cheap-ok` / `standard` / `strong-required`）を1つ付与する。判断材料は `task.yml` の "強いモデルを要する兆候" チェックボックス
- GitHub Actions（`claude-issue-triage` / `claude-mention` / `claude-pr-review`）と CLI のルーティング指針は `docs/handoff/ai-execution.md`
- 詳細運用は `docs/handoff/README.md`、AI 向け最短ルールは `.claude/rules/handoff.md`

## Decision Priorities

<!-- @stack:replace -->
1. TODO
2. TODO
3. 実装の単純さ
<!-- @stack:end -->

## Things To Avoid

- 最初から全部入りにすること
- データモデルを決めずに実装から入ること
- 不確実なまま推測で埋めること
