# Plan: Codex PR review 導入（label 選択式）

## Context

`anthropics/claude-code-action@v1` の upstream regression（[issue #1290](https://github.com/anthropics/claude-code-action/issues/1290)、2026-05-06 ~05:38 UTC〜）で 6 リポの claude-* workflow が全停止。`.claude/rules/handoff.md` の DoD は「`claude-pr-review.yml` の review 通過」を必須にしているため、修正待ちでは全 PR が DoD 未達で詰まる。

upstream 復旧は不確実。Codex review を**選択式**で導入し、PR ごとに claude / codex / 両方を選べるようにする。

## 確定方針

| 軸 | 決定 |
|---|---|
| Tool | `openai/codex-action@v1`（公式、5軸 prompt 自前書き） |
| Trigger | PR label `review: claude` / `review: codex` で起動 |
| Default | PR open 時に `review: claude` を auto-add（既存運用互換） |
| 両方 label | claude + codex を両方走らせる（second opinion） |
| 展開 | template + 1 検証リポ（x-post-archive-extension）→ 残り 4 派生 PJ |

## 状態遷移

```
PR open
  │
  ▼
pr-auto-label.yml ──▶ `review: claude` を自動付与
  │
  ▼ (pull_request.labeled で発火)
  ├── label = `review: claude`  ──▶ claude-pr-review.yml 起動
  ├── label = `review: codex`   ──▶ codex-pr-review.yml 起動
  └── label = 両方              ──▶ 両方起動

claude が壊れてる現状での運用:
  作成者が `review: claude` を剥がして `review: codex` に張替 → codex のみ動く
  もしくは両方付けて second opinion を取る
```

## 依存グラフ

```
[A] env: codex + OPENAI_API_KEY secret（人間作業）
       │
       ▼
[B] labels.yml に `review: claude` / `review: codex` 追加
       │
       ▼
[C] pr-auto-label.yml 新規（PR open 時に default ラベル付与）
       │
       ▼
[D] claude-pr-review.yml の if 条件に label check 追加
[E] codex-pr-review.yml 新規（5軸 + verdict classifier）
       │
       ▼
[F] rework-tracker.yml が codex verdict marker も拾う
       │
       ▼
[G] DoD docs 緩和（AI review = claude OR codex pass）
       │
       ▼
[H] 1 検証リポへ展開
       │
       ▼
[I] 残り 4 派生 PJ へ並列展開
```

## Phase 1 — template で review unblock

### Task 1.1: labels.yml にラベル追加

**File**: `.github/labels.yml`

追加:
- `review: claude` — Trigger Claude PR review (#7C3AED)
- `review: codex` — Trigger Codex PR review (#0F766E)

**Acceptance**: `node scripts/sync-labels.mjs` で 2 ラベルが GitHub に同期される

**Verification**: `gh label list --limit 50 | grep "^review:"` で2件出る

### Task 1.2: pr-auto-label.yml 新規追加

**File**: `.github/workflows/pr-auto-label.yml`

```yaml
on:
  pull_request:
    types: [opened]
permissions:
  pull-requests: write
jobs:
  auto-label:
    runs-on: ubuntu-latest
    steps:
      - run: gh pr edit ${{ github.event.pull_request.number }} --add-label "review: claude"
        env:
          GH_TOKEN: ${{ github.token }}
```

**Acceptance**: 新規 PR を立てると `review: claude` が自動付与される

**Verification**: test PR 作成 → 数秒で label が付く

### Task 1.3: claude-pr-review.yml の if 条件に label gate 追加

**File**: `.github/workflows/claude-pr-review.yml`

変更:
- on: trigger に `pull_request.labeled` 追加（label 付与で再発火するため）
- `review` job の if 条件に `contains(github.event.pull_request.labels.*.name, 'review: claude')` 追加

**Acceptance**: `review: claude` label が付いてる PR でのみ動く

**Verification**: label 剥がした PR に push しても claude review は起動しない

### Task 1.4: codex-pr-review.yml 新規追加

**File**: `.github/workflows/codex-pr-review.yml`

**構造** (claude-pr-review.yml と対称):
- on: `pull_request: opened / synchronize / ready_for_review / labeled`（draft 除外）
- permissions: `contents: read`, `pull-requests: write`, `id-token: write`, `actions: read`
- jobs:
  - `check-secrets`: `OPENAI_API_KEY` 存在確認、無ければ skip + warning
  - `review` (`needs: check-secrets`):
    - if: secret あり + draft 除外 + `contains(labels, 'review: codex')`
    - `environment: codex`
    - step 1: `openai/codex-action@v1` で 5軸 review prompt 実行 → review コメント post（先頭に `[codex]` prefix で claude review と区別）
    - step 2: verdict classifier — review 本文を読んで `<!-- ai-review-verdict-codex: approved | changes-requested-minor | changes-requested-major -->` marker を別コメントで post

**Prompt**: `claude-pr-review.yml` の 5軸 prompt をベースに、Codex 向け微調整。Learning notes セクションは parity のため同形式で出す。

**Acceptance**:
- secret 未設定時: `check-secrets` が `has_token=false` で `review` を skip
- `review: codex` label 無し: review job が if で skip
- secret + label あり: review コメント + verdict marker 2件が PR に post される

**Verification**: template に test PR 立てて `review: codex` 付与 → workflow 完走

### Task 1.5: rework-tracker.yml を codex marker 対応へ拡張

**File**: `.github/workflows/rework-tracker.yml`

変更:
- trigger 条件: 本文に `ai-review-verdict-codex: changes-requested-major` も含める
- script: regex を `ai-review-verdict(-codex)?:` に拡張、source（claude / codex）を抽出
- 重複防止: 同 PR で「同じ source の major」が複数立っても rework count は1回のみ加算（既存ロジック）。**claude と codex が両方 major を出した場合は2回加算** — 異なる視点の指摘は別カウントが妥当

**Acceptance**: claude only / codex only / 両方 major / approved 各ケースで期待通り

**Verification**: codex review が major verdict を post → `rework: 1` が PR + 関連 Issue に付与される

### Task 1.6: DoD docs 緩和

**Files**:
- `.claude/rules/handoff.md` — DoD 6状態フロー L3「`claude-pr-review.yml` review 通過」→「**AI review 通過（claude OR codex のいずれか pass、両方 fail なら block）**」
- `docs/handoff/ai-execution.md` — §3 に `codex-pr-review.yml` / `pr-auto-label.yml` 説明追加、§9 Human acceptance 3点ゲート 1.「AI review OK」を「claude OR codex」と明記、§4 Claude/Codex 役割分担表に「差分レビュー: Claude (Action) or Codex (Action) — `review:` ラベルで選択」を追記
- `docs/handoff/README.md` — 状態遷移図 / ラベル一覧に `review: claude` / `review: codex` 追加
- `docs/decisions/0003-human-acceptance-and-ai-tutor.md` — 「Codex review 並走（label 選択式）」セクション追記
- `docs/handoff/bootstrap.md` — §2 後ろに codex env 作成手順 + `OPENAI_API_KEY` 取得手順、§4 動作確認に `review: codex` ケース追加

**Acceptance**: DoD が「claude OR codex どちらか pass で OK、両方 fail なら NG」と読める。label 運用が明文化されている

**Verification**: 5 ファイルの diff を読んで矛盾なし

### Phase 1 Checkpoint

- [ ] template の test PR で:
  - PR open → `review: claude` 自動付与
  - `review: claude` 剥がし `review: codex` 付与 → codex のみ起動
  - 両方 label → 両方起動
- [ ] codex review 完走（5軸 + verdict marker）
- [ ] rework-tracker が codex major verdict 対応
- [ ] DoD 5 ファイルの記述整合
- [ ] **人間 OK 後 Phase 2 へ**

## Phase 2 — 1 検証リポ（x-post-archive-extension）へ展開

### Task 2.1: x-post-archive-extension 反映

**人間作業**（先行）:
- `Settings → Environments → New environment` → `codex`（保護なし）
- `OPENAI_API_KEY` を env に登録

**コード作業**:
- `.github/labels.yml` に 2 ラベル追加
- `pr-auto-label.yml` を template から copy
- `claude-pr-review.yml` の if 条件に label gate 追加
- `codex-pr-review.yml` を template から copy
- `rework-tracker.yml` を template の拡張版へ更新
- `chore/<N>-codex-pr-review` branch で PR 作成

**Acceptance**: x-post-archive-extension で `review: codex` ラベル付き PR が完走、claude review が壊れてても DoD 満たせる

**Verification**: x-post-archive-extension で trivial PR 立て、`review: codex` のみ付与で codex review 完走 → 「AI review (codex) 通過」で DoD 完了 → merge

### Phase 2 Checkpoint

- [ ] x-post-archive-extension で codex review 完走
- [ ] 1 件 merge して人間 acceptance まで通せた
- [ ] **人間 OK 後 Phase 3 へ**

## Phase 3 — 残り 4 派生 PJ へ並列展開

### Task 3.1-3.4

対象: STS2_oekaki_patch / godot-ai-walker / translation-platform / tech-articles

各リポで **人間作業（先行）**:
- env: codex 作成 + `OPENAI_API_KEY` 登録（template/x-post-archive-extension で使った値の copy で可）

各リポで **コード作業**（4 PJ 並列、Agent で fan-out）:
- labels.yml + pr-auto-label.yml + claude-pr-review.yml の label gate + codex-pr-review.yml + rework-tracker.yml 更新
- `chore/<N>-codex-pr-review` で PR 作成

**Acceptance**: 各リポで env: codex に secret 登録 + workflow merge 済み

**Verification**: 各リポで次の PR で label 動作確認

### Phase 3 Checkpoint

- [ ] 4 派生 PJ で codex review 動作確認
- [ ] 全 6 リポで「label 選択式」運用確立

## Out of scope

- `claude-mention.yml` / `claude-issue-triage.yml` の codex 版（review unblock 最優先、別 issue 切出し）
- Codex CLI のローカル運用変更
- ADR-0003 の全面書き換え（追記のみ）
- claude-code-action 復旧後の cleanup（claude を残すか剥がすかは別判断）
- `model:` ラベルとの統合（`model:` は Issue 単位のモデル選定、`review:` は PR 単位のレビュアー選定で軸が別）

## Risks

- `openai/codex-action@v1` の prompt 互換性が将来の major で崩れる → SHA pin で当面回避
- OpenAI API rate limit / quota → Anthropic と OpenAI 双方の枠監視が必要
- codex review 品質が claude と同等保証なし → DoD 「片方 pass」で品質不足でも block しない設計
- `review: claude` を default にしてるが claude が壊れてる現状では fail 確定 → 人間が手動で `review: codex` に張替が必要（運用ドキュメントに明記）
- 両方 label でコスト 2倍 → 必要時のみ second opinion で使う運用ガイドを書く
- pr-auto-label が既存 PR に付け直すと workflow が二重起動 → on `opened` 限定で抑止

## Critical files

新規:
- `.github/workflows/pr-auto-label.yml`
- `.github/workflows/codex-pr-review.yml`

拡張:
- `.github/workflows/claude-pr-review.yml`（label gate + labeled trigger）
- `.github/workflows/rework-tracker.yml`（codex verdict marker）
- `.github/labels.yml`（2 ラベル追加）

更新:
- `.claude/rules/handoff.md`
- `docs/handoff/ai-execution.md`
- `docs/handoff/README.md`
- `docs/handoff/bootstrap.md`
- `docs/decisions/0003-human-acceptance-and-ai-tutor.md`

参考（既存・流用元）:
- `.github/workflows/claude-pr-review.yml`（prompt 移植元）

## Verification 全体

1. **template Phase 1**: test PR で label 切替動作確認 + codex review 完走 + rework-tracker 動作 + docs 整合
2. **検証リポ Phase 2**: x-post-archive-extension で 1 PR を完走 + 人間 acceptance まで
3. **全展開 Phase 3**: 4 派生 PJ で各 1 PR で label 動作確認

各 phase 末に人間 checkpoint。OK なら次へ。

## 最終アーティファクト

承認後、以下を保存:
- `tasks/plan.md` — 本 plan のコピー
- `tasks/todo.md` — phase ごとの todo リスト（チェックボックス形式）
