# ADR-0002: GitHub 運用の SoT を `.github/` 配下と `scripts/commit-msg` に集約する

## Status

Accepted

## Date

2026-04-30

## Context

ADR-0001 で template repository 戦略を確定した結果、複数 PJ で同じ GitHub 運用ルール（ラベル / Issue / workflow / commit hook）を回す必要が出た。実態としては以下の問題があった：

- ラベルの定義が `gh label create` の手作業履歴に依存し、PJ 間でドリフトしていた
- Issue Template が PJ ごとに微妙に違い、AI が読む前提のフォーマットが揺れていた
- AI 実行制御（Issue triage / @claude / PR review）を自作スクリプトで組もうとしたが、`anthropics/claude-code-action` と GitHub `gh-aw` で代替できることが調査で判明した（`docs/findings/2026-04-30-ai-workflow-survey.md`）
- commit message の `#<issue>` 強制が hook 経由で動いていたが、ADR としての裏付けが無く、新規 PJ で外されるリスクがあった

要件：

- GitHub 運用の決定事項をリポジトリ内の機械可読アーティファクトに集約する（口伝・README 散逸を排除）
- AI が自作スクリプト群を再生成しなくて済むよう、公式 Action ベースに寄せる
- 既存の Issue lifecycle governance（status / owner / human-only close / `#<issue>` 強制）の核は維持する
- 周辺（model 軸 / 振り返りラベル / AI 実行制御）は公式機能に乗せて軽量化する

## Decision

GitHub 運用の Single Source of Truth を以下の4アーティファクトに固定する：

- `.github/labels.yml` — ラベル定義（status / owner / priority / type / area / model / cost / model-was-overkill）
- `.github/ISSUE_TEMPLATE/` — Issue Template（task / bug / investigation + config.yml で blank 無効化）
- `.github/workflows/` — Actions（sync-labels / claude-issue-triage / claude-mention / claude-pr-review）
- `scripts/commit-msg` + `scripts/check-commit-message.mjs` — `#<issue>` 強制 hook

これらの整合性は `.github/workflows/sync-labels.yml` と `scripts/setup-hooks.sh` が機械的に保つ。AI 実行制御は `anthropics/claude-code-action@v1` を OAuth で呼び出す方式を採用し、自作スクリプトはゼロにする。

具体構成：

- **ラベル軸**: status（todo/in-progress/blocked/ready-for-close）/ owner（claude/codex/human）/ priority（high/medium/low）/ type（feature/bug/investigation/refactor）/ area（PJ 固有）/ **model（cheap-ok/standard/strong-required）** / **振り返り（cost: overrun / model: was-overkill）**
- **Issue Template**: task.yml に「強いモデルを要する兆候」チェックボックスを置き、`model:` ラベル選択の根拠を機械可読に残す
- **Actions**: claude-code-action を OAuth で起動。初期は API キー不要。CI 利用がサブスク枠を圧迫したら従量課金に切替
- **commit-msg**: `<type>: <subject> (#<issue>)` 形式必須、escape は `[skip-issue]` のみ、`--no-verify` での回避は禁止
- **ルーティング指針**: GitHub.com の Agents タブ model picker と `model:` ラベルは「推奨／実行時最終決定」の2層に分離し、矛盾時は Issue コメントに理由を1行残す
- **横展開**: 新規 PJ は ADR-0001 の template 経由、既存 PJ への取り込みは差分 PR を別途立てる

関連資料：

- 詳細運用: `docs/handoff/README.md`、`docs/handoff/ai-execution.md`
- AI 向け最短ルール: `.claude/rules/handoff.md`
- 調査根拠: `docs/findings/2026-04-30-ai-workflow-survey.md`
- 関連コミット: `e062249` (AI execution control layer 投入)

## Alternatives Considered

### A. 自作の `issue-pack` / `ai-state` / `ai-route` スクリプト群を中核に置く

- Pros: 完全に自分たちの要求にフィットさせられる
- Cons: claude-code-action と gh-aw が同等以上を提供しており、自作はメンテ負債。Issue 全体を毎回 AI に読ませない設計は Action 側でも実現できる
- **Rejected**: 車輪の再発明。findings 調査で公式機能が十分に成熟している確認が取れた

### B. ラベル軸に `risk:` / `context:` を追加して多軸管理する

- Pros: モデル選択以外の判断軸（リスク許容度、Issue サイズ）を独立に表現できる
- Cons: 軸が増えるほど貼り忘れと矛盾が出る。`model:` 1軸 + Issue Template チェックボックスで根拠を残せば十分
- **Rejected**: findings §軽量化の「label より session/picker に寄せる」流れと逆行

### C. SoT を Notion / Linear など外部 PM ツールに置く

- Pros: PM 機能は GitHub Issue より豊富
- Cons: AI が直接アクセスできるツール統合がまだ薄く、commit / PR との結び付きが弱まる。個人〜小規模 PJ には over-kill
- **Rejected**: 現状規模では GitHub Issue の表現力で足りる

## Consequences

### Positive

- 「この運用ルールはどこに書いてある？」の答えが `.github/` と `scripts/commit-msg` の2箇所に固定される
- AI が新規 PJ でも同じアーティファクトを読めば運用に乗れる
- claude-code-action ベースなので、自作スクリプトのメンテが発生しない
- ラベル・テンプレ・workflow・hook が同じリポジトリ内で diff 可能になり、改善が PR で表現できる

### Negative / Trade-offs

- claude-code-action / gh-aw が破壊的変更を入れた場合、追従 PR が必要
- `model:` ラベルと GitHub UI のモデルピッカーは二重管理。整合性は人間の運用ルール（矛盾時にコメント1行）で吸収
- OAuth 連携は Claude サブスク枠を消費する。CI 利用が増えたら API キー切替を検討（`docs/handoff/ai-execution.md` §8）
- AI が誤って `status: ready-for-close` を貼る可能性がある。close 権限は人間に残すことで吸収

### Migration

- 新規 PJ: ADR-0001 の template 経由で全部入りで起動。`/install-github-app` を1回叩くだけ
- 既存 PJ: 別途差分 PR を立てる。最小取り込みは `.github/labels.yml` の `model:` / `cost:` / `model: was-overkill` 追記と `.github/workflows/claude-*.yml` 3本のコピー
- 既に動いている `commit-msg` hook は変更不要。`scripts/setup-hooks.sh` の挙動も変えない
