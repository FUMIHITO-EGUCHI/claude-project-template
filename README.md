# claude-project-template

新規プロジェクトを立ち上げるときの雛形。Claude Code + Codex + 人間 1 名による多 AI 開発体制を前提に、以下を即座に揃える。

- `CLAUDE.md` / `AGENTS.md` — 行動原則と AI 役割分担
- `.claude/rules/` — handoff / TypeScript / Windows shell encoding の path-scoped ルール
- `.github/ISSUE_TEMPLATE/` — Task / Bug / Investigation
- `.github/labels.yml` + sync workflow — `status:` / `owner:` / `priority:` / `type:` / `area:` の 5 軸ラベル
- `docs/handoff/` — GitHub Issues ベース handoff 運用ガイド
- `docs/decisions/` — ADR ひな形 + 参考 ADR
- `scripts/` — commit-msg hook（`#<issue>` 強制）+ setup-hooks

## 使い方

### 1. 新規 PJ の作成

このリポジトリを GitHub 上で **Template repository** として登録した上で:

```sh
gh repo create my-new-project --template FUMIHITO-EGUCHI/claude-project-template --private --clone
cd my-new-project
```

### 2. 初期化

```sh
sh scripts/init-project.sh
```

対話で以下を聞かれる:

- プロジェクト名（CLAUDE.md / AGENTS.md / README.md の `<!-- @project:name -->` を置換）
- プロジェクト概要（`<!-- @project:description -->` を置換）

スクリプトは以下も実行する:

1. git hooks のインストール（`commit-msg` + `pre-commit`）
2. ラベルの GitHub 同期（`gh label create` を `.github/labels.yml` から for ループ）
3. テンプレ自身の README をプロジェクト用に置き換える提案

### 3. 残った `<!-- @stack:replace -->` ブロックを書き換え

`CLAUDE.md` / `AGENTS.md` の以下を実 stack に合わせて書き換える:

```sh
grep -rn '@stack:replace' .
```

該当ブロック内の TODO を埋めれば完了。

## ラベル

| Category | 値 |
|---|---|
| `status:` | `todo` / `in-progress` / `blocked` / `ready-for-close` |
| `owner:` | `claude` / `codex` / `human` |
| `priority:` | `high` / `medium` / `low` |
| `type:` | `feature` / `bug` / `investigation` / `refactor` |
| `area:` | プロジェクトごとに `.github/labels.yml` を編集 |

詳細は `docs/handoff/README.md`。

## 設計判断

- ADR-0001: Template repository 戦略（`docs/decisions/`）
