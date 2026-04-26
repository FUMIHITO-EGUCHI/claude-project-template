# ADR-0001: AI handoff / task management を GitHub Issues + Projects v2 に移行する

## Status

Accepted

## Date

2026-04-22

## Context

本リポジトリは 1 名の human + Claude + Codex による 3 者開発体制。タスク管理に `ai-handoff/` 配下の Markdown ファイル群（`current-task.md` / `tasks/*.md` / `findings/*.md` / `templates/`）と、整合性を確認する Node スクリプト（`sync-handoff.mjs` / `check-handoff-consistency.mjs` / `log-changes.mjs`）を運用していた。

運用中に以下の課題が顕在化した:

1. **状態遷移が見えにくい**: 未着手 / 進行中 / ブロック中 / 完了 が、Markdown 本文の自然文に埋もれ、一目で把握できない
2. **ブランチ差分が汚れる**: タスクの作成・編集ごとに feature branch の diff にタスクファイル変更が混入。レビュー時のノイズが多く、マージ順で取りこぼしが発生
3. **複数 AI の同一ファイル編集競合**: Claude と Codex が `current-task.md` を並行で書き換え、片方の更新が失われるケース
4. **完了の証跡が非構造**: `## Result` / `## Verification` / `## Changed files` といったチェック項目が存在しても、ファイルのどこに書くかが揺れる
5. **AI が独断で完了扱いする可能性**: close の権限境界がファイル運用では強制しづらい

要件は次のとおり:

- タスク状態がボード上で一目で分かる（human view）
- AI が Markdown を編集してもブランチ diff に混入しない
- 複数 AI の同時編集が構造的に衝突しない
- 完了は人間のみが確定できる（AI は申請まで）
- 既存ワークフロー（feature branch / typecheck / build）を壊さない
- 無料で使えること。外部 SaaS は課金対象外

## Decision

タスク管理を **GitHub Issues + Projects v2（ボード名: X Archive Handoff）** に全面移行する。

具体構成:

- **Backend**: GitHub Issues（private repo 内）
- **Human view**: GitHub Projects v2 ボード。列は `Todo / In Progress / Blocked / Ready for Close / Done`、group by `owner` ラベル
- **AI interface**: [`github/github-mcp-server`](https://github.com/github/github-mcp-server)（MCP stdio）と `gh` CLI を併用
- **ラベル体系**: `status:` / `owner:` / `priority:` / `type:` / `area:` の 5 軸。`status: done` は作らず **close 状態 = done** と扱う
- **Issue テンプレ**: `.github/ISSUE_TEMPLATE/{task,investigation,bug}.yml`。blank issue は無効化
- **Findings（長文調査ノート）**: `docs/findings/` に直置き（private repo 前提）。個人情報が混入する例外ケースのみ Secret Gist。Issue からリンク
- **Commit 参照強制**: `commit-msg` hook が `#<issue>` または `[skip-issue]` の有無を検査（`scripts/check-commit-message.mjs`）
- **AI 間 handoff**: 構造化コメント（`## Handoff` / From / To / Done so far / Blocker / Next step suggestion / Related）を投稿後、`owner:` ラベルを付け替え
- **close は人間のみ**: AI は `status: ready-for-close` ラベル + 最終コメント（`## Result` / `## Verification` / `## Changed files`）で申請

関連資料:

- 仕様: `SPEC.md`
- 運用ガイド: `docs/handoff/README.md`
- AI 向け最短ルール: `.claude/rules/handoff.md`
- 移行コミット: `3cb8529`
- Meta tracking issue: #9

## Alternatives Considered

### A. 既存 `ai-handoff/` ファイル運用の継続 + 整合性スクリプト強化

- Pros: 移行コストゼロ。外部依存なし
- Cons: 根本原因（ブランチ diff 混入・並行編集競合・状態可視化）が解消しない。スクリプト追加は対症療法
- **Rejected**: 課題 1〜3 が構造的にファイル運用では解けない

### B. 外部 SaaS（Linear / Jira / Notion）

- Pros: 専用ツールとして UX が高い。ボード・自動化が充実
- Cons: 課金 or フリープラン制限。リポジトリ外に真実が移り、コミットとの参照が弱くなる。private repo との同期を別途維持する必要
- **Rejected**: 無料縛り + コミット参照強制（`#<issue>`）の手軽さは GitHub 統合が最強

### C. ローカル SQLite + 独自ビューア

- Pros: 完全オフライン。構造データで競合しづらい
- Cons: human view のための UI を自作する必要。レビュー・履歴・コメントを自前実装するのは過剰投資
- **Rejected**: 1 人開発で自作ボードを保守するコストが本業を圧迫

### D. Gist のみ（Issue を使わず全て Gist で管理）

- Pros: private repo と別領域で diff 混入なし
- Cons: ボード機能なし。状態遷移・ラベル・テンプレが使えない。Gist は長文調査向けで、タスク管理には構造不足
- **Rejected**: 当初は長文 findings を Secret Gist に切り出す案だったが、検索性喪失のコストが大きく、private repo 内の `docs/findings/` 直置きに改めた

### E. GitHub Issues のみ（Projects v2 なし）

- Pros: 最低限の構成。学習コスト低
- Cons: 列ボードがないと human view で「一目で分かる」要件を満たせない。`status:` ラベルを見て回る手間が残る
- **Rejected**: Projects v2 は無料で利用可。採用しない理由がない

## Consequences

### Positive

- ブランチ diff からタスクファイルの変更が消え、レビューノイズが激減
- 状態遷移がボード列移動として視覚化される
- `owner:` ラベル + handoff コメントで並行編集が構造的に回避される
- `commit-msg` hook で全コミットに Issue 参照を強制できる（雑務は `[skip-issue]` escape）
- Issue コメントが追記専用運用となり、編集競合が起きない
- AI による close 暴走を権限で封じられる（GitHub 側の権限設計で確実）

### Negative / Trade-offs

- GitHub の障害時にタスク操作ができない（許容: private repo のため稀)
- ラベル管理が増える。新規ラベル追加には手作業が必要
- MCP 経由の操作はトークン消費が Markdown 編集より多い
- findings は `docs/findings/` 直置きとし、リポジトリ内検索で原文がヒットする。将来 OSS 化する際は sanitization pass（自分の username / profile path などの置換）を別途実施する想定。現時点では private repo 前提で運用コストを抑える

### Migration

- Active / waiting の Issue のみ新規作成（1 件: Issue #8 の大容量 restore timeout）
- 完了済み 56 packet は `ai-handoff/archive/` に残し、新規追記は禁止
- `package.json` の `precommit:check` から `handoff:check` を除去済
- 旧スクリプト（`sync-handoff.mjs` 等）は Phase G で削除予定（運用試験 F1/F2 完了後）

### Operational rules established

- Issue 作成は Claude / Codex / human いずれも可（テンプレ必須、初期ラベル 5 軸）
- AI は Issue を close しない
- Issue 本文の編集は objective / scope / checklist メンテナンスのみ。経過はコメント
- AI 間割り込みは handoff コメント必須
- commit message は `<type>: <subject> (#<issue>)` 形式、`--no-verify` 禁止
