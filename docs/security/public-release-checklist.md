# Public Release Checklist

private repo を public 化する前に必ず通すチェックリスト。
**一度でも Git に入った secret は削除ではなく失効・再発行が原則**。push して履歴に入った時点で「漏洩した」と扱う。

---

## 1. Secret scan（必須）

### 1.1 working tree

```sh
sh scripts/security-scan.sh --full
```

### 1.2 git history 全体

```sh
sh scripts/security-scan.sh --history
```

### 1.3 手動 grep（gitleaks 漏れ対策）

API key prefix / JWT / PEM ヘッダ等の典型パターン:

```sh
git log -p --all -S 'BEGIN PRIVATE KEY' -- '*.pem' '*.key'
git log -p --all -S 'AKIA' -- ':!*.lock'             # AWS access key
git log -p --all -S 'AIza'                            # Google API key
git log -p --all -S 'ghp_'                            # GitHub PAT
git log -p --all -S 'sk-' -- ':!*.lock'              # OpenAI / Anthropic
git log -p --all -S 'eyJ' | head -200                # JWT (base64 header)
```

検出された場合: **削除ではなく失効・再発行**。`git filter-repo` で履歴書き換えする場合も、まず secret を rotate してから。

---

## 2. GitHub 上のアセット

`gh` CLI で公開される全要素を点検:

```sh
# Issue / PR 本文・コメント（過去に貼り付け事故）
gh issue list --state all --limit 200 --json number,title,body
gh pr list   --state all --limit 200 --json number,title,body
# コメントは個別に: gh api repos/<owner>/<repo>/issues/<n>/comments

# Workflow runs / artifacts / logs
gh run list --limit 100
gh api repos/<owner>/<repo>/actions/artifacts --jq '.artifacts[] | {id,name}'

# Releases assets
gh release list

# Packages（GHCR / npm 等）
gh api /users/<owner>/packages

# Wiki / Discussions / Pages
# UI で確認 + git clone <repo>.wiki.git
```

artifact / log に secret が含まれた可能性があれば **削除 + secret rotate**。

---

## 3. ローカル / 設定ファイル

| ファイル | 確認内容 |
|---|---|
| `.env*` | `.gitignore` に入って untracked か |
| `.mcp.json` | MCP サーバー設定に API key 直書きないか |
| `.claude/settings.local.json` | 個人 username / token / 絶対パス |
| `.vscode/settings.json` | secret や個人パス |
| `*.har` / `exports/` | 通信ログに認証 header / cookie |
| `coverage/` `dist/` | bundle 内に .env 内容が混入 |

```sh
git ls-files | grep -E '\.(env|pem|key|har)$|credentials|secret'
```

---

## 4. 実データ

- **DB dump** (`*.sql` `*.dump`) — 個人情報・本番データなし
- **fixture / seed** — 実顧客データを含むテストデータなし
- **screenshot / 動画** — 画面に token / 顧客名が映ってない

---

## 5. AI / agent 設定

| 確認対象 | 内容 |
|---|---|
| `CLAUDE.md` / `AGENTS.md` | 社内固有名詞・URL・人名 |
| `.claude/rules/` | path-scoped rules に内部情報 |
| `prompt cache` / chat log の commit | 過去会話の貼り付けなし |

---

## 6. 公開直前

- [ ] `git log --oneline | wc -l` で履歴サイズ確認（過剰なら squash 検討）
- [ ] `LICENSE` 存在
- [ ] `SECURITY.md` の報告先が現役
- [ ] README の連絡先が個人 mail 直書きでない
- [ ] Settings → Manage access で意図しない collaborator なし
- [ ] Branch protection（main への direct push 禁止 / 必須レビュー）

---

## 7. 公開後

- [ ] 1 週間後: `gh api repos/<owner>/<repo>/traffic/clones` でアクセス監視
- [ ] security workflow（gitleaks / Trivy / shellcheck / semgrep）が PR 毎に走っていること（[`.github/workflows/security.yml`](../../.github/workflows/security.yml)）
- [ ] dependabot PR が来たらマージ運用
- [ ] Issue / PR の不審な活動（大量 spam、bot 攻撃）を週次で確認
