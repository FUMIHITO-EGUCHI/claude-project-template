# Bootstrap — 他 PJ への展開手順

このテンプレを別 PJ に適用するときの最短手順。`init-project.sh` がカバーしない部分（GitHub App 連携、workflow 検証、ハマりどころ）を集約する。

詳細な運用ルールは [`README.md`](./README.md) と [`ai-execution.md`](./ai-execution.md) を参照。

---

## 0. 前提

- GitHub リポジトリ作成済み（public / private どちらでも可）
- ローカルに `gh` CLI が入っていて `gh auth status` が通る
- Claude Code CLI が入っていて Pro / Max サブスクで OAuth 連携可能（または Anthropic API キーを持っている）
- Node 18+ / bash（Windows は Git Bash か WSL）

---

## 1. テンプレ展開

```bash
# 1-a. テンプレから新 PJ を作る
gh repo create <owner>/<new-pj> --template <owner>/claude-project-template --private --clone
cd <new-pj>

# 1-b. プレースホルダ置換 + hooks + ラベル同期を一括
sh scripts/init-project.sh "<new-pj>" "短い説明"
```

`init-project.sh` がやること:

1. `CLAUDE.md` / `AGENTS.md` / `README.md` / `package.json` のプレースホルダ置換
2. `commit-msg` / `pre-commit` hook をインストール（pre-commit は staged 差分の secret scan 込み、`gitleaks` 未インストールでも commit はブロックしない）
3. `.github/labels.yml` を GitHub に同期（`status:` 7種 + `model:` 3種 + `cost: overrun` 等）

### Security CI（自動）

`.github/workflows/security.yml` で **gitleaks**（secret）/ **Trivy**（dep vuln + IaC misconfig、HIGH/CRITICAL のみ）/ **shellcheck**（shell lint、warning level）/ **semgrep**（`p/shell` + `p/secrets`、shell security policy）を並列実行。`.github/dependabot.yml`（npm + github-actions weekly）も併走。

ローカルで同等 scan するには `sh scripts/security-scan.sh --all`（各ツール個別実行は `--trivy` / `--shellcheck` / `--semgrep` 等）。public 化前は [`docs/security/public-release-checklist.md`](../security/public-release-checklist.md) を必ず通す。

---

## 2. GitHub App 連携（claude-code-action 必須）

3 つの workflow（triage / mention / pr-review）はすべて `anthropics/claude-code-action@v1` を使う。これを動かすには **`CLAUDE_CODE_OAUTH_TOKEN` secret が必要**。

```bash
# Claude Code CLI 内で実行
/install-github-app
```

これで以下が起きる:

- GitHub App が当該リポに install される
- リポジトリ Secret に `CLAUDE_CODE_OAUTH_TOKEN` が自動登録される

### 注意: 自動生成される workflow を削除

`/install-github-app` は副作用として **`.github/workflows/claude-code-review.yml` を勝手に作る**（汎用 PR レビュー workflow）。本テンプレの `claude-pr-review.yml` と機能が重複するため削除する:

```bash
rm .github/workflows/claude-code-review.yml
git add -A && git commit -m "chore: remove auto-generated claude-code-review.yml [skip-issue]"
git push
```

放置すると PR ごとにレビュー Action が2本走る。

---

## 3. workflow が main に乗っているか確認

`claude-code-action` のセキュリティ仕様で、**PR ブランチの workflow ファイルは default branch（main）の同名ファイルと内容が一致していないと 401 で落ちる**。

つまり workflow を編集する PR は、その編集内容を main にマージするまでは Action が動かない。Bootstrap 時は次の順で進める:

1. テンプレからコピーした 3 workflow をそのまま main に push（編集なし）
2. 動作確認後、必要なカスタマイズ（prompt 文言など）を別 PR で main に直接マージ
3. 通常の feature PR で workflow をいじらない

---

## 4. 動作確認（3点）

PJ 立ち上げ時に必ず踏む:

### 4.1 Issue triage

```bash
gh issue create --title "[task] dummy triage test" --body "objective: smoke test for claude-issue-triage" --label "status: todo"
```

- `claude-issue-triage.yml` が起動する
- 数十秒後に `model:` / `type:` / `area:` ラベルが自動で付く
- 短い triage コメントが付く

### 4.2 @claude mention

上記 Issue に以下のコメントを付ける:

```
@claude このリポの README に書いてある技術スタックを1行で要約して
```

- `claude-mention.yml` が起動する
- `track_progress` が進捗コメントを upsert する
- 最終応答が返る

### 4.3 PR review + Learning notes

```bash
git checkout -b test/pr-review-smoke
echo "" >> docs/handoff/README.md
git add -A && git commit -m "test: trigger pr review (#<n>)"
git push -u origin test/pr-review-smoke
gh pr create --title "test: pr review smoke" --body "smoke test"
```

- `claude-pr-review.yml` が起動
- 5軸レビューの inline comment + summary
- **summary 末尾に `## Learning notes for the human` セクションが必ず出る**（ADR-0003）

確認後、PR は merge せず close。

---

## 5. ハマりどころ（Bootstrap 時の典型エラー）

| 症状 | 原因 | 対処 |
|---|---|---|
| `Either ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN is required` | secret 未設定 or workflow `with:` に書いてない | `/install-github-app` を実行 + workflow `with:` に `claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}` 配線 |
| `Workflow validation failed. ...identical content to the version on the repository's default branch` | workflow を PR ブランチでだけ書き換えた | main に直接マージしてから PR 作業 |
| `Claude Code is not installed on this repository` | GitHub App 未 install | `/install-github-app` 実行 |
| `gh label list` で `status:` が 4 個しか見えない | `gh` 既定の出力上限 | `gh label list --limit 50` |
| PR ごとに review Action が 2 本走る | `claude-code-review.yml` 残留 | 当該ファイル削除して push |
| commit が hook で reject される | message に `#<issue>` が無い | `<type>: <subject> (#<n>)` 形式に修正。雑務は `[skip-issue]` |

---

## 6. PJ 固有のカスタマイズ

`init-project.sh` 完了後に手動で:

1. **`.github/labels.yml` の `area:` ラベル** — PJ のディレクトリ構造に合わせて編集 → `node scripts/sync-labels.mjs` で再同期
2. **`CLAUDE.md` / `AGENTS.md` の `<!-- @stack:replace -->` ブロック** — 技術スタック・コマンド表を埋める
3. **`docs/decisions/` に PJ 固有 ADR** — 0001 / 0002 / 0003 はテンプレ由来。0004 以降に PJ 判断を積む
4. **`Projects v2` ボード** — GitHub UI で 1 枚作成。Columns: Todo / In Progress / Blocked / Evidence Required / Accepted / Done
5. **`init-project.sh` を削除** — 1 回限りのスクリプトなので残さない

---

## 7. Bootstrap 完了の判定

以下が全部 yes になったら他 PJ 展開完了:

- [ ] `gh label list --limit 50` で `status:` 7種 + `model:` 3種 + `owner:` / `priority:` / `type:` / `area:` / `cost:` がある
- [ ] ダミー Issue で `claude-issue-triage.yml` が動いた
- [ ] ダミー Issue で `@claude` mention が動いた
- [ ] ダミー PR で `claude-pr-review.yml` が動き、`## Learning notes for the human` が出た
- [ ] `git commit -m "chore: test"`（`#<n>` 抜き）が hook で reject される
- [ ] `npm run typecheck` / `npm run build` が通る（PJ 固有実装後）

---

## 8. 参考

- 運用ガイド: [`README.md`](./README.md)
- AI 実行制御の詳細: [`ai-execution.md`](./ai-execution.md)
- ADR: [`docs/decisions/`](../decisions/)
