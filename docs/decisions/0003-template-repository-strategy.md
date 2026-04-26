# ADR-0003: 新規 PJ の立ち上げを GitHub Template repository で標準化する

## Status

Accepted

## Date

2026-04-26

## Context

`x-post-archive-extension` で育てた多 AI 開発体制（Claude + Codex + 人間 1 名）の運用一式は、新規プロジェクトを立ち上げるたびに以下を毎回手作業で再構築していた。

- `CLAUDE.md` / `AGENTS.md` の行動原則・handoff セクション
- `.claude/rules/` の path-scoped ルール（handoff / typescript / powershell-encoding）
- `.github/ISSUE_TEMPLATE/` 一式
- ラベル（status / owner / priority / type / area の 5 軸）— 手動 `gh label create`
- `docs/handoff/README.md` の handoff ガイド
- `commit-msg` hook（`#<issue>` 強制）と setup スクリプト

要件:

- 新規 PJ の立ち上げを「分単位」に短縮
- stack 非依存の運用ルールはそのまま継承
- stack 依存部分（package.json / 一部 .claude/rules）は埋めやすい形で残す
- 既存プロジェクトの運用は壊さない

## Decision

新規リポジトリ `kurahuta/claude-project-template` を作成し、GitHub の **Template repository** 機能で配布する。展開後は `scripts/init-project.sh` でプレースホルダ置換と hook 設置・ラベル同期を行う。

具体構成:

- **配布**: `gh repo create my-new --template kurahuta/claude-project-template --private --clone`
- **stack 依存部分**: `<!-- @stack:replace --> 〜 <!-- @stack:end -->` ブロックで囲み、init 後に手動で書き換え。`init-project.sh` が grep で残存検出する
- **ラベル**: `.github/labels.yml` を single source of truth とし、`.github/workflows/sync-labels.yml` が main 更新時に `gh label create` で同期
- **skill 設定**: `.claude/settings.json` には permissions のみ。skill 一覧は `.claude/SKILLS.md` に列挙（user-global で enable される前提）

## Alternatives Considered

### A. ローカル雛形フォルダを `cp -r` で展開

- Pros: GitHub に依存しない。完全オフライン
- Cons: ラベル・workflow・GitHub 設定（template repo flag, Projects 連携）が一発で立ち上がらない。Repo の作成が別工程
- **Rejected**: 立ち上げの最大ボトルネックが GitHub 側設定なので、そこを取り込めない

### B. stack ごとに別テンプレ（web-extension / cli / web-app）

- Pros: 展開直後から build が通る
- Cons: テンプレが増えるほど運用ルール側の更新が分散しメンテが重い。stack の数 × 運用更新コストになる
- **Rejected**: stack 部分はプレースホルダで残し、運用ルールを 1 本に保つ方が ROI が高い

### C. `degit` 等の汎用テンプレツール

- Pros: GitHub 非依存。任意の URL から雛形を引ける
- Cons: GitHub Template repo 機能は無料・GitHub が公式対応。新規依存を増やす意味がない
- **Rejected**: 機能差分が無いのに依存を増やす利点がない

## Consequences

### Positive

- 新規 PJ で「立ち上げ作業」と呼べるものが `init-project.sh` 1 回 + `<!-- @stack:replace -->` 埋めだけになる
- handoff 運用・hooks・ラベルが全プロジェクトで揃う（複数 PJ の同時オペレーションが楽になる）
- 運用ルール改善が template repo に集約され、各 PJ の取り込みは「テンプレからの差分マージ」で表現できる

### Negative / Trade-offs

- template repo 自体のメンテが新たに発生する
- 既存 PJ への運用更新の波及は手動（差分マージか手作業コピー）
- `<!-- @stack:replace -->` 系プレースホルダの埋め忘れが起きうる → init スクリプトで残存検出して警告

### Migration

- 既存 `x-post-archive-extension` には `.github/labels.yml` + `sync-labels.yml` を backport（`area:` は viewer/content/background/db/handoff/other を維持）
- 既存ラベルは `gh label create --force` で description / color のみ更新。手作業で作ったラベルが消えないことを確認
- 旧 PJ の `CLAUDE.md` / `AGENTS.md` は変更しない（運用差分は ADR で吸収）
