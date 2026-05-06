# Codex PR review 導入 — TODO

issue #52 / branch `feature/52-codex-pr-review`

## Phase 1 — template で review unblock

### Task 1.1 — labels.yml にラベル追加
- [ ] `review: claude` (#7C3AED) — Trigger Claude PR review
- [ ] `review: codex` (#0F766E) — Trigger Codex PR review
- [ ] `node scripts/sync-labels.mjs` で動作確認（merge 後の Action で sync）

### Task 1.2 — pr-auto-label.yml 新規追加
- [ ] `pull_request: opened` で起動
- [ ] `gh pr edit --add-label "review: claude"` を実行
- [ ] permissions: `pull-requests: write`

### Task 1.3 — claude-pr-review.yml に label gate 追加
- [ ] `on: pull_request.types` に `labeled` を追加
- [ ] `review` job の if 条件に `contains(github.event.pull_request.labels.*.name, 'review: claude')`
- [ ] `check-secrets` job も同条件で skip させる（不要なら触らない）

### Task 1.4 — codex-pr-review.yml 新規追加
- [ ] on: `pull_request: opened / synchronize / ready_for_review / labeled`（draft 除外）
- [ ] permissions: `contents: read`, `pull-requests: write`, `id-token: write`, `actions: read`
- [ ] `check-secrets` job — `OPENAI_API_KEY` 存在確認、無ければ skip + warning
- [ ] `review` job — `environment: codex`, label gate, `openai/codex-action@v1`
  - [ ] step 1: 5軸 review prompt（claude のものから移植、`[codex]` prefix）+ Learning notes
  - [ ] step 2: verdict classifier — `<!-- ai-review-verdict-codex: ... -->` marker

### Task 1.5 — rework-tracker.yml 拡張
- [ ] trigger 条件に `ai-review-verdict-codex: changes-requested-major` 追加
- [ ] script の regex を `ai-review-verdict(-codex)?:` に拡張
- [ ] source 別に rework count（claude と codex 両方 major で 2 加算）
- [ ] 既存 claude only ケースの後方互換性維持

### Task 1.6 — DoD docs 緩和
- [ ] `.claude/rules/handoff.md` — DoD L3「AI review 通過（claude OR codex pass）」
- [ ] `docs/handoff/ai-execution.md` — §3 / §4 / §9 更新
- [ ] `docs/handoff/README.md` — ラベル一覧に `review:` 追加
- [ ] `docs/handoff/bootstrap.md` — §2 codex env 作成手順、§4 動作確認に `review: codex` ケース
- [ ] `docs/decisions/0003-human-acceptance-and-ai-tutor.md` — Codex review 並走セクション

### Phase 1 Checkpoint
- [ ] template の test PR で：
  - [ ] PR open → `review: claude` 自動付与
  - [ ] `review: claude` 剥がし `review: codex` 付与 → codex のみ起動
  - [ ] 両方 label → 両方起動
- [ ] codex review 完走（5軸 + verdict marker）
- [ ] rework-tracker が codex major verdict 対応
- [ ] **人間 OK 後 Phase 2 へ**

---

## Phase 2 — x-post-archive-extension へ展開

### Task 2.1
- [ ] **人間作業**: env: codex 作成 + OPENAI_API_KEY 登録
- [ ] labels.yml にラベル追加
- [ ] pr-auto-label.yml copy
- [ ] claude-pr-review.yml に label gate
- [ ] codex-pr-review.yml copy
- [ ] rework-tracker.yml 拡張
- [ ] PR 作成 → merge

### Phase 2 Checkpoint
- [ ] x-post-archive-extension で codex review 完走
- [ ] 1 件 merge して人間 acceptance まで通せた
- [ ] **人間 OK 後 Phase 3 へ**

---

## Phase 3 — 残り 4 派生 PJ へ並列展開

### Task 3.1 — STS2_oekaki_patch
- [ ] **人間作業**: env: codex + OPENAI_API_KEY
- [ ] workflow 一式反映 → PR

### Task 3.2 — godot-ai-walker
- [ ] **人間作業**: env: codex + OPENAI_API_KEY
- [ ] workflow 一式反映 → PR

### Task 3.3 — translation-platform
- [ ] **人間作業**: env: codex + OPENAI_API_KEY
- [ ] workflow 一式反映 → PR

### Task 3.4 — tech-articles
- [ ] **人間作業**: env: codex + OPENAI_API_KEY
- [ ] workflow 一式反映 → PR

### Phase 3 Checkpoint
- [ ] 4 派生 PJ で codex review 動作確認
- [ ] 全 6 リポで「label 選択式」運用確立
