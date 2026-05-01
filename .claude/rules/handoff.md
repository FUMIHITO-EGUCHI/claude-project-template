---
paths:
  - docs/handoff/**/*.md
  - ai-handoff/**/*.md
  - .github/ISSUE_TEMPLATE/**
---

# AI Handoff Rules (Issue-based)

タスク管理は **GitHub Issues + Projects v2** を single source of truth とする。
運用ガイド全文は `docs/handoff/README.md`。ここでは AI が守るべき最短のルールだけを置く。

## Single source of truth

- タスクの状態・担当・経過はすべて **GitHub Issue** にある
- Issue 本文の編集は objective / scope / checklist のメンテナンスのみ
- 経過・考察・結果は **Issue コメント** に追記する（本文は書き換えない）
- 旧 `ai-handoff/tasks/*.md` `current-task.md` は廃止。参照用の履歴は `ai-handoff/archive/` のみ

## Labels と状態遷移

| Category | 値 |
|---|---|
| `status:` | `todo` / `in-progress` / `blocked` / `review-pending` / `evidence-required` / `accepted` / `ready-for-close` |
| `owner:` | `claude` / `codex` / `human` |
| `priority:` | `high` / `medium` / `low` |
| `type:` | `feature` / `bug` / `investigation` / `refactor` |
| `area:` | `viewer` / `content` / `background` / `db` / `handoff` / `other` |

- `status: done` は存在しない。完了は **close 状態**で表現
- **close は人間のみ**。AI は絶対に `gh issue close` しない

## 作業フロー

0. **作成**: Claude / Codex / human いずれも作成可。テンプレ選択（task / investigation / bug）→ 初期ラベル `status: todo` + `owner:` + `priority:` + `type:` + `area:`。他 AI に投げる場合は `owner: <相手>` で止める。自分で着手するなら 1 へ。
1. **着手**: `status: todo` を外し `status: in-progress` を付ける。必要なら `owner:` を自分に。
2. **進捗**: 意味あるステップごとに Issue コメントを追記（`YYYY-MM-DD <自分>:` で始める）
3. **ブロック時**: `status: in-progress` を外し `status: blocked` を付け、理由をコメント
4. **完了申請（ADR-0003 6状態フロー）**:
   - PR 作成後: `in-progress` → `review-pending`（claude-pr-review.yml が起動）
   - review 通過後: `review-pending` → `evidence-required`。Issue Template の "Evidence of acceptance" 手順を実機で実行し、結果を1コメントに：
     - `## Result`（3〜10 行で要約）
     - `## Verification`（typecheck / build の末尾）
     - `## Evidence`（手順の実行結果 / スクショ / ログ）
     - `## Changed files`（`git diff --name-only` 結果）
     - `## Rework count`（`rework: N`）
   - 人間が evidence を見て OK なら `evidence-required` → `accepted` → close
   - **旧フロー** (`ready-for-close`) も互換のため残しているが、新規 Issue は上記6状態フローを使う

## AI 間 handoff

`status: in-progress` 中の Issue に他 AI が割り込む場合は **必ず handoff コメント**を残す:

```markdown
## Handoff
- From: <自分>
- To: <相手>

### Done so far
### Blocker
### Next step suggestion
### Related
```

コメント投稿後、`owner:` を相手に付け替え、`status: in-progress` を外し `status: todo` に戻す。

## Commit message

- 形式: `<type>: <subject> (#<issue>)`
- 雑務 escape: `[skip-issue]`
- `commit-msg` hook が自動検査。`--no-verify` で回避しない

## Definition of Done（ADR-0003 6状態フロー）

1. `npm run typecheck` pass
2. `npm run build` pass
3. `claude-pr-review.yml` の review 通過
4. `status: evidence-required` 付与 + Result / Verification / Evidence / Changed files / Rework count が揃ったコメント1件
5. commit message に `#<issue>` 含む
6. 人間が evidence を確認し `status: accepted` を付ける（AI 対象外）
7. 人間が Issue を close（AI 対象外）

## Never

- AI が自発的に Issue を close する
- handoff コメントなしで他 AI の in-progress Issue を横取りする
- Issue コメントを **編集・削除** する（追記のみ）
- Gist / Issue に秘匿情報（`.env` 等）を載せる
- commit message から `#<issue>` を省いて push する（escape なし）
- `--no-verify` で hook を回避する
