# AI Handoff — Issue-based Workflow

このリポジトリのタスク管理は **GitHub Issues + Projects v2** を single source of truth とする。運用ルールの根拠は ADR-0002（`docs/decisions/0002-github-operation-sot.md`）、Human acceptance と学習ループは ADR-0003（`docs/decisions/0003-human-acceptance-and-ai-tutor.md`）に集約する。

- Backend: GitHub Issues
- Human view: GitHub Projects v2 ボード（プロジェクトごとに 1 枚作成）
- AI interface: `gh` CLI
- ラベル定義: `.github/labels.yml`（`sync-labels.yml` workflow が main 更新時に同期）

---

## 1. Labels

| Category | 値 |
|---|---|
| `status:` | `todo` / `in-progress` / `blocked` / `review-pending` / `evidence-required` / `accepted` / `ready-for-close` |
| `owner:` | `claude` / `codex` / `human` |
| `priority:` | `high` / `medium` / `low` |
| `type:` | `feature` / `bug` / `investigation` / `refactor` |
| `area:` | プロジェクトごとに `.github/labels.yml` で定義 |
| `model:` | `cheap-ok` / `standard` / `strong-required`（AI 実行制御。詳細は [ai-execution.md](./ai-execution.md)） |

- 「done」は **close 状態**で表現する（`status: done` ラベルは存在しない）
- close は**人間のみ**が行う

### 状態遷移（ADR-0003 以降）

```
todo → in-progress → review-pending → evidence-required → accepted → close
                  ↘ blocked ↗
```

- `review-pending`: AI 実装完了、PR 作成済み。`claude-pr-review.yml` の review agent 確認中
- `evidence-required`: review 通過後、AI が `task.yml` の "Evidence of acceptance" 手順を実機で実行し、結果を Issue に貼った状態。**人間 acceptance 待ち**
- `accepted`: 人間が evidence を確認し OK と判定。close 待ち
- `ready-for-close`: ADR-0003 以前の旧フロー互換。新規 Issue は上記6状態フローを使う

人間は `evidence-required` 状態の Issue で **コードを読まずに** evidence を確認するだけが正規ルート（ADR-0003）。

---

## 2. Issue の種類とテンプレート

GitHub の New Issue から選ぶ:

- **Task** — 実装粒度のタスク（feature / refactor）
- **Investigation** — 調査・再現・原因切り分け。成果物は Secret Gist もしくは Issue コメント
- **Bug** — 既存機能の不具合

blank issue は無効化している。

---

## 3. AI の作業フロー

### 3.0 Issue 作成

作成者は Claude / Codex / human いずれも可。

1. New Issue からテンプレを選ぶ（実装=Task / 調査=Investigation / 不具合=Bug）
2. 初期ラベルを付ける:
   - `status: todo`（テンプレで自動付与）
   - `owner:` 自分で着手するなら自分、他 AI に投げるなら相手
   - `priority:` `high` / `medium` / `low`
   - `type:` `feature` / `bug` / `investigation` / `refactor`
   - `area:` プロジェクトの `.github/labels.yml` を参照
3. 自分で即着手するなら 3.1 に進み `status: todo` を外し `status: in-progress` に遷移
4. 他 AI に投げるなら `status: todo` + `owner: <相手>` で止める。相手が着手時にラベル操作

タスク分解が必要な大きめ Issue は、子 Issue を複数作り親 Issue 本文 checklist に `- [ ] #<子>` で並べる。

### 3.1 着手

1. ボードか `gh issue list` で自分の担当 Issue を選ぶ
2. **owner ラベルを確認**。他 AI が in-progress 中なら着手しない（handoff コメントがある場合は引き継ぐ）
3. `status: todo` を外し `status: in-progress` を付ける
4. 必要なら `owner:` を自分に付け替える

### 3.2 作業中

- 意味のあるステップごとに **Issue コメントを追記**（本文は編集しない）
  - 先頭フォーマット: `YYYY-MM-DD <自分>:`
  - 例: `2026-04-22 Claude: 調査完了。原因は X。次に Y を試す`
- Issue 本文（body）の編集は **objective / scope / checklist のメンテナンスのみ**。経過はコメントで表現
- ブロックされたら `status: in-progress` を外し `status: blocked` を付け、理由をコメント

### 3.3 完了申請（AI による）— 6状態フロー（ADR-0003）

1. **PR 作成後**: `status: in-progress` を外し `status: review-pending` を付ける。`claude-pr-review.yml` が起動して 5軸レビューを inline comment する
2. **review 通過後**: `status: review-pending` を外し `status: evidence-required` を付ける。同時に Issue Template の "Evidence of acceptance" 手順を実機で実行し、結果（出力 / スクリーンショット / ログ）を Issue コメントに貼る
3. **evidence コメントには以下を含む**:

```markdown
## Result
<実装内容の要約を 3〜10 行で>

## Verification
<`npm run typecheck` の出力（末尾 20 行程度）>
<`npm run build` の出力（末尾 20 行程度）>

## Evidence
<task.yml の "Evidence of acceptance" 手順を実行した結果>
<スクリーンショット / 出力 / ログを貼る>

## Changed files
<`git diff --name-only <base>..HEAD` の結果>

## Rework count
rework: 0  # 自分が evidence を貼り直した回数。rejected → 修正 → 再 evidence で +1
```

4. **AI は close しない**。`status: evidence-required` で人間の確認待ちに入る
5. **人間の操作**: evidence を見て OK なら `status: evidence-required` を外し `status: accepted` を付け close。NG なら理由をコメントし `status: in-progress` に戻す（rework count +1）

### 3.3-legacy 旧フロー（ready-for-close）

ADR-0003 以前から進行中の Issue 互換のため、`status: ready-for-close` も残してある。新規 Issue は上記 6 状態フローを使う。

### 3.4 Close（人間のみ）

人間が内容を確認し、実機検証が必要なら実施。問題なければ `gh issue close <n>` または UI で close。

---

## 4. AI → AI handoff（引き継ぎ）

Codex が解決できず Claude に渡したい（または逆）の場合:

1. 以下のコメントを投稿する（下の雛形をコピペ）
2. `owner:` を相手に付け替え
3. `status: in-progress` を外し `status: todo` に戻す（相手が着手したら再 in-progress）

### 4.1 Handoff コメント雛形

```markdown
## Handoff

- From: <自分>
- To: <相手>

### Done so far
- <そこまでの到達点を箇条書き>

### Blocker
- <何で詰まったか>
- <出たエラー文・試した手段・仮説>

### Next step suggestion
- <相手に何をしてほしいか>

### Related
- <参照した findings Gist / PR / コミット>
```

handoff 手順を踏めば、相手 AI は割り込みではなく引き継ぎとして自由に着手してよい。

---

## 5. Commit message ルール

すべての commit は Issue を参照する。

### 5.1 形式

```
<type>: <subject> (#<issue>)
```

例:
```
feat: add date-range filter (#42)
fix: restore progress bar update on large backup (#8)
refactor: extract archive-maintenance helper (#13)
```

### 5.2 Escape hatch

雑務コミット（typo 修正、README の微調整など）は `[skip-issue]` を含める:

```
chore: fix typo in docs [skip-issue]
```

許容範囲は **本質的に検証不要なレベルの変更**に限る。

### 5.3 Hook

`scripts/setup-hooks.sh` を実行すると `commit-msg` hook が入り、上記を自動検査する。
`--no-verify` での回避は**しない**（hook が落ちたら根本原因を直す）。

---

## 6. Findings / 長文調査ノート

- 原則 **`docs/findings/` に直置き**（private repo の場合）
- ファイル名: `YYYY-MM-DD-<topic>.md`
- 先頭に frontmatter を付ける:
  ```yaml
  ---
  date: 2026-01-01
  related-issue: 10
  status: open | resolved | superseded
  ---
  ```
- Issue 本文の `## Notes` または該当コメントから `docs/findings/...` をリンク
- findings 自体に close 概念はない。調査 Issue を close したら frontmatter の `status` を `resolved` にする

### 例外: Secret Gist

秘匿情報（個人情報、API キー、外部ユーザー ID など）が混入する場合のみ Secret Gist を使う。Issue からリンクし、ローカルには持たない。

### public repo の場合

リポジトリを公開する場合は `docs/findings/` を Secret Gist に切り出すか、sanitization pass（個人情報・パス・ID の置換）を必ず実施する。

---

## 7. Projects v2 ボード

人間 1 名がプロジェクトごとに 1 枚作成（GitHub UI から）。

- Columns: Todo / In Progress / Blocked / Ready for Close / Done
- Group by: `owner` ラベル
- Filter: `priority` ラベル

Issue を作ると自動でボードに乗るよう auto-add ワークフローを設定する。状態遷移はラベル変更で反映される。

---

## 8. Definition of Done（ADR-0003 6状態フロー）

AI が満たす（1〜5）:

1. `npm run typecheck` pass
2. `npm run build` pass
3. `status: evidence-required` ラベルが付いている
4. Evidence コメントに `## Result` / `## Verification` / `## Evidence` / `## Changed files` / `## Rework count` が揃っている
5. commit message に `#<issue>` が含まれている

人間が満たす（6〜7）:

6. Evidence の内容を確認し `status: accepted` を付ける
7. Issue を close する

**旧フロー互換**: `status: ready-for-close` も残してあるが、新規 Issue は上記を使う。

---

## 9. よくある質問

**Q. 小さすぎて Issue を立てるほどでもない修正は？**
A. `[skip-issue]` escape を使う。ただし後から「なぜこの変更が？」と聞かれたら答えられる範囲に限る。

**Q. 同じタスクを両 AI で並行できないか？**
A. 原則不可。owner が切り替わる handoff でのみ引き継ぐ。並行作業は衝突コストが高い。

**Q. Issue の body を書き換えていい？**
A. objective / scope / checklist のメンテナンスのみ。経過・考察・結果はコメントで。

**Q. issue を立てる前に CLI で gh label を確認したい**
A. `gh label list --limit 50` で確認できる（既定は出力切れる）。ラベル定義は `.github/labels.yml`、main 更新時に `sync-labels.yml` workflow が同期する。

**Q. このテンプレを別 PJ に展開したい**
A. [`bootstrap.md`](./bootstrap.md) を参照。`init-project.sh` + `/install-github-app` + 動作確認3点で完了。
