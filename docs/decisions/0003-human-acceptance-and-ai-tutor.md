# ADR-0003: Human acceptance を evidence ベースに固定し、AI を学習補助として併用する

## Status

Accepted

## Date

2026-04-30

## Context

ADR-0002 で GitHub 運用 SoT を確定したが、以下の根本問題が残っていた：

- 開発者（人間 1 名）は **PJ で使われている言語・スタックを完全には読めない**。AI 提案を技術的に判定する力が現状不十分
- それでも close は人間のみという governance を維持している。実態として **rubber-stamp になるリスク**が高い
- findings (`docs/findings/2026-04-30-ai-workflow-survey.md`) §計測と失敗事例 でも「巨大 AI PR を人が毎回読み切るのは持続しない」が失敗パターンとして報告されている
- 人間が確実にできるのは「実機で動かして期待挙動か確認」「自分の意図とのズレ判定」「アイディア壁打ち」であり、「コードの正しさを読んで判定」はできない

要件：

- 人間 acceptance を「コードを読まずに OK/NG 判定できる仕組み」に固定する
- 技術的妥当性は AI（review agent）に任せ、人間は end-to-end の挙動と意図整合性に集中する
- 同時に、人間が長期的に技術力を上げる学習導線を運用に組み込む（governance だけでは技術的負債を防げない）
- 学習導線が「説明を読むだけで身に付かない」失敗を回避するため、公式ドキュメント参照と手を動かすステップを必須化する

## Decision

acceptance を3点ゲート方式にする：

- **AI review agent OK**（claude-pr-review.yml の 5軸レビュー pass）
- **CI green**（typecheck / build / test）
- **Human evidence verification**（人間が Issue Template の "Evidence of acceptance" 手順を実機で確認）

人間はコードを読まない。代わりに「指定の手順を実行し、期待挙動が出ることを確認する」だけを担う。同時に、PR レビューの末尾に **Learning notes** セクションを AI が自動生成し、人間が用語と公式ドキュメントへの導線を毎 PR で受け取る。

具体構成：

- **Issue Template (`task.yml`) に必須項目追加**: "Evidence of acceptance"（コードを読まずに accept できる手順を記述。AI が完了申請時に実行して証跡を貼る）
- **status state machine 拡張**: `todo → in-progress → review-pending → evidence-required → accepted → close` の 6 状態。`evidence-required` は AI が evidence を貼った状態、`accepted` は人間が確認 OK の状態
- **claude-pr-review.yml の prompt 拡張**: レビュー出力末尾に "## Learning notes for the human" を追加。PJ 固有の概念最大3つ + 公式ドキュメントリンク + 1分以内で試せる小実験
- **学習ログ `docs/learning/YYYY-MM.md`**: 月1ファイル。月末に AI が「その月の PR で出てきた新しい概念」を集約し、人間が「自分で説明できるか」チェックボックスを埋める運用
- **`@claude explain` 質問テンプレ**: `claude-mention.yml` 用の質問フォーマットを `docs/handoff/ai-execution.md` に明記。「自分の理解 / 詰まっている部分 / learning level」を先に書かせる
- **rework count コメント**: Issue クローズ時に `rework: N (理由)` を1行残す。月次で `rework: 0` 比率を見て Issue 仕様精度と AI 品質を振り返る

関連資料：

- 詳細運用: `docs/handoff/ai-execution.md`（実装後に §Human acceptance / §Learning loop を追記）
- 調査根拠: `docs/findings/2026-04-30-ai-workflow-survey.md`
- 親 ADR: ADR-0002

## Alternatives Considered

### A. 人間がコードを読めるようになるまで governance で踏ん張る

- Pros: 王道。長期的には技術力が上がる
- Cons: 短期的には rubber-stamp 化が止められない。技術力獲得には数ヶ月〜年単位かかる。その間に蓄積する技術的負債を governance だけでは防げない
- **Rejected**: 単独では機能しない。学習は採用するが、それだけに依存しない

### B. close 権限も AI に渡す（人間関与を最小化）

- Pros: ボトルネック解消、スループット最大化
- Cons: AI の誤動作・誤解釈を止める層が完全に消える。findings §軽量化でも human-only close は「コストに対し守備力が高い」と評価
- **Rejected**: 人間が ideation と acceptance に関与することで、AI が暴走方向に流れる確率を下げる効果は維持したい

### C. evidence-required state を作らず、現行の ready-for-close のまま運用する

- Pros: 状態数が少なく運用が軽い
- Cons: 「AI が evidence を貼った状態」と「人間が確認した状態」が区別できず、人間が確認したか曖昧になる。rubber-stamp の温床
- **Rejected**: 状態の区別が rubber-stamp 防止の核心

### D. 学習を governance に組み込まず別管理（読書のみ）

- Pros: シンプル
- Cons: PJ で実際に出てきた概念と学習が紐づかず、抽象的な学習に終わる。findings §計測と失敗事例の「学んだ気になる」失敗パターンに該当
- **Rejected**: PR と学習を結び付ける導線が ROI 高い

## Consequences

### Positive

- 人間が「コードを読めない」前提を直視した運用になり、rubber-stamp 化を構造的に防げる
- 技術力獲得が運用に組み込まれ、毎 PR で必ず学びの導線が走る
- evidence ベースの acceptance により「動くが意図と違う」実装を早期に弾ける
- rework count メトリクスで Issue 仕様精度と AI 品質を月次で改善できる

### Negative / Trade-offs

- status の状態数が増え、ラベル運用がやや重くなる（4状態 → 6状態）
- 完了までの工程に「AI が evidence を実機で実行・撮影」ステップが入る。実行環境を持たない workflow（純ライブラリ等）では evidence 手順を別途定義する必要あり
- Learning notes が PR ごとに増える。情報過多になるリスクは月次集約で吸収
- 学習ログの「自分で説明できるか」チェックを人間が埋めない場合、学習導線が形骸化。月次振り返りで運用負荷を見て調整する余地を残す

### Migration

- ラベル `status: review-pending` / `status: evidence-required` / `status: accepted` を `.github/labels.yml` に追加、sync-labels で反映
- `task.yml` に "Evidence of acceptance" 必須項目を追加
- `claude-pr-review.yml` の prompt に Learning notes セクション生成を追記
- `docs/handoff/ai-execution.md` に Human acceptance / Learning loop / @claude explain テンプレを追記
- `docs/learning/` ディレクトリ作成、初月（2026-05）から運用開始
- 既存 Issue は移行不要。新規 Issue から新 state machine 適用
