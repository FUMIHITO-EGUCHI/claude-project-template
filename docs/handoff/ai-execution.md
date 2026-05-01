# AI 実行制御レイヤー

`docs/handoff/README.md` の上に乗る薄い層。**Issue 管理は SoT**のまま、Claude Code / Codex への仕事の振り方とコスト管理だけを扱う。

自作スクリプトは置かない。**GitHub / Anthropic 公式と既存ツールの組み合わせ**で成立させる。

---

## 1. 全体像

```
GitHub Issue / PR
   │
   ├─[issues opened]──▶ claude-issue-triage.yml   → model:/type:/area: 自動付与
   ├─[@claude mention]─▶ claude-mention.yml       → 質問/調査/実装（track_progress）
   └─[pull_request]───▶ claude-pr-review.yml      → 5軸レビュー

ローカル CLI:
   Claude Code (Opus 4.7 主担当: 調査・要件整理・ブラウザデバッグ)
   Codex      (実装担当)
```

---

## 2. ラベル運用（`model:` 軸）

| ラベル | 使う場面 |
|---|---|
| `model: cheap-ok` | 候補抽出 / 整形 / 要約 / 単純 rename / Issue コメント整形 |
| `model: standard` | 既存パターンに沿った実装 / テスト追加 / 型修正 / 軽微な UI 修正 |
| `model: strong-required` | 認可 / DB / migration / 状態管理 / 並行処理 / 曖昧仕様 / 根本原因調査 / 不可逆変更 / 複数ファイル横断設計 |

判定根拠は Issue Template (`task.yml`) の **「強いモデルを要する兆候」チェックボックス**。1つでも該当すれば `strong-required`。

### 振り返り用ラベル（完了申請時に自分で貼る）

- `cost: overrun` — 想定より燃えた（軽量で済むと思ったが手戻りした 等）
- `model: was-overkill` — strong を選んだが standard で足りた

月1で `gh issue list --label "cost: overrun"` を眺め、判定基準を改善する。

---

## 3. Workflows

### 3.1 `claude-issue-triage.yml`

- 発火: `issues: opened`
- やること: ラベル取得 → `model:` / `type:` / `area:` を1つずつ付与 → 短い triage コメント
- 触らない: `status:` / 本文 / 既存ラベル削除 / close

### 3.2 `claude-mention.yml`

- 発火: コメント本文に `@claude` を含む / Issue が `claude` に assign された
- やること: 依頼内容に応じて応答（質問 / 調査 / 実装 / レビュー）
- 進捗管理: `track_progress: true` が自動でコメント1件を upsert する。**人間/他 AI はそのコメントを触らない**
- 完了申請: `status: ready-for-close` 付与 + Result / Verification / Changed files の最終コメント
- 触らない: close / 本文編集 / `[skip-issue]` 濫用 / `--no-verify`

### 3.3 `claude-pr-review.yml`

- 発火: `pull_request: opened / synchronize / ready_for_review`（draft は除外）
- やること: 5軸（correctness / readability / architecture / security / performance）で diff レビュー、重要箇所に inline comment、軽微指摘は summary 1件
- 触らない: merge / close / approve

---

## 4. Claude Code / Codex の役割分担

| 場面 | 担当 | 備考 |
|---|---|---|
| Issue triage | Claude (Action) | 軽量で十分だが判断ミスを避けるため Sonnet |
| 要件整理 / 設計判断 / 根本原因調査 | Claude Code (Opus) | ローカル or @claude mention |
| ブラウザ / CDP デバッグ | Claude Code | DevTools MCP を持つ |
| ready-for-impl の実装 | Codex | Issue 本文に `implement:` で明示 |
| 差分レビュー | Claude (Action) | claude-pr-review.yml |
| ドキュメント整理 / コミット整形 | Codex or Claude (cheap-ok) | どちらでも可 |

ルーティングを workflow 単位で固定化したくなったら **`github/gh-aw` (GitHub Agentic Workflows)** で engine を `codex` に切り替えた workflow を追加する。MVP では未導入。

---

## 5. モデル選択

二重管理に注意する。優先順位:

1. **GitHub.com の Agents タブのモデルピッカー** — 実行時に人間が選ぶ最終決定
2. **Issue の `model:` ラベル** — 推奨値。Action / 人間が貼る
3. **CLAUDE.md / AGENTS.md の役割記述** — デフォルト方針

`model:` ラベルと UI 選択が矛盾した場合は、Issue コメントに理由を1行残す（後の振り返り用）。

参考: <https://github.blog/changelog/2026-04-14-model-selection-for-claude-and-codex-agents-on-github-com/>

---

## 6. コスト管理（任意）

### `claude-code-router` (CCR)

ローカル CLI のコスト上限管理プロキシ。Opus を本当に必要なときだけ呼び、それ以外は安いモデルへ振る。MVP では強制しない。導入時は CCR README を参照。

### `ccusage`

セッション単位の使用量集計。

```bash
npx ccusage@latest
```

`cost: overrun` ラベルと組み合わせて、Issue 単位の手戻りを月次で振り返る。

---

## 7. やってはいけないこと

- Action から Issue を close する（close は人間のみ）
- Action から PR を merge / approve する
- `track_progress` コメントを手書きで触る
- `model:` ラベルを2つ以上貼る（1つだけ）
- `risk:` / `context:` ラベルを後付けで作る（model: 軸に集約済み）
- `[skip-issue]` を実装系コミットで使う
- 自作の issue-pack / ai-state スクリプトを作る（公式 Action が代替）

---

## 8. セットアップ

新 PJ 立ち上げ手順は [`bootstrap.md`](./bootstrap.md) に集約。要点だけ:

1. `sh scripts/init-project.sh "<pj>" "<desc>"` でプレースホルダ置換 + hooks + ラベル同期
2. Claude Code CLI で `/install-github-app` 実行 → `CLAUDE_CODE_OAUTH_TOKEN` secret が自動登録
3. **副作用で生成される `claude-code-review.yml` は削除**（`claude-pr-review.yml` と重複）
4. 各 workflow の `with:` に `claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}` が配線済みであること
5. workflow 編集は **default branch (main) と PR branch の内容を一致させる**（claude-code-action のセキュリティ仕様。PR branch でだけ workflow を変えると 401）

ハマりどころ表は [`bootstrap.md` §5](./bootstrap.md#5-ハマりどころbootstrap-時の典型エラー) 参照。

workflow 側に `anthropic_api_key:` は **書かない**（OAuth 経由で認証）。

### 将来検討：Anthropic API キー導入

CI 利用がサブスク枠を圧迫する／コスト予測を独立させたいときは、従量課金の API キーに切替検討する。

判断基準（どれかに該当したら検討）:
- claude-code-action 起動でローカル Claude Code が頻繁にレートリミットに当たる
- 月次の使用量振り返り（`ccusage` + `cost: overrun` ラベル）で CI 起動の比重が高い
- サブスクと CI のコストを会計上分離したい

切替手順:
1. <https://console.anthropic.com/> で API キー発行 → クレジット購入
2. リポジトリ Settings → Secrets → `ANTHROPIC_API_KEY` を登録
3. 各 workflow の `with:` に `anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}` を追記

---

## 9. Human acceptance（ADR-0003 3点ゲート）

人間がコードを読まずに accept できる前提で運用する。3点ゲート全部通過で完了：

1. **AI review OK** — `claude-pr-review.yml` の 5軸レビュー（correctness / readability / architecture / security / performance）通過
2. **CI green** — typecheck / build / test pass
3. **Human evidence verification** — Issue Template の "Evidence of acceptance" 手順を AI が実機で実行し、出力／スクショ／ログを Issue に貼った状態を、人間が確認

人間がやること：

- Issue 作成時に「コードを読まずに accept できる手順」を Evidence 欄に記入する
- `status: evidence-required` になった Issue で、AI が貼った evidence を見る
- 期待挙動と一致 → `status: accepted` を付け close
- 不一致 → 理由をコメントし `status: in-progress` に戻す（`rework: N` ラベルは rework-tracker.yml が AI review NG 時に自動加算。人間の差し戻しでもカウントしたい場合は手動でラベル増やすか reason をコメントに残す）

人間がやらないこと：

- コードの正しさを読んで判定する（review agent と CI に任せる）
- アーキテクチャ妥当性を読んで判定する（review agent に任せる）

---

## 10. Learning loop（ADR-0003）

### 10.1 PR ごとの Learning notes

`claude-pr-review.yml` が PR レビュー末尾に "## Learning notes for the human" セクションを自動生成する。最大3概念 + 公式ドキュメントリンク + 1分で試せる小実験。Hallucination 抑制のため「リンク提供不可なら出さない」が prompt に明記してある。

### 10.2 月次学習ログ

`docs/learning/YYYY-MM.md` を月1ファイルで作成。月末に AI に集約を依頼：

```
@claude この月（YYYY-MM）の closed Issue / merged PR から、Learning notes に出てきた概念を集約して docs/learning/YYYY-MM.md に追記して
```

人間は「自分で説明できるか」チェックボックスを埋める。埋まらなければその月の理解が浅い証拠。

### 10.3 `@claude explain` 質問テンプレ

理解が浅いコードを読みたいときは、`claude-mention.yml` 経由で以下の形式で質問する：

```
@claude explain
- file: <path>
- what I think it does: <自分の理解を先に書く>
- where I'm stuck: <分からない部分>
- learning level: 言語は分かるが <stack> は初見
```

「自分の理解を先に書く」のがコツ。書けない時点で読めていないと自覚できる。

### 10.4 並行する読書

AI 説明だけでは抽象的な体系が抜けるため、PJ で使う主要ライブラリ・言語の入門書を1冊だけ並行で進める。AI の説明はその索引として機能する。

---

## 11. Rework count

### 11.1 自動集計（rework-tracker.yml）

`claude-pr-review.yml` は2 step 構成: (1) 5 軸レビュー本文を post、(2) review-classifier step が本文を読んで verdict marker（`<!-- ai-review-verdict: ... -->`）だけを別コメントで post。後者は条件なしで毎 PR 動く。`rework-tracker.yml` がその marker を grep し、`changes-requested-major` のときに **PR とその PR が `Closes/Refs #N` で参照する Issue 全部に `rework: N` ラベルを increment**。`minor` 指摘や `approved` ではカウントしない。

ラベル定義（`.github/labels.yml`）:

- `rework: 1` / `rework: 2` / `rework: 3+`（3 以上は飽和）

### 11.2 reason を残す（任意）

ラベルだけでは「何が原因で rework したか」が消えるため、close 時の最終コメントに以下のような1行を残すと月次振り返りに効く:

- `rework: 2 (gitleaks-action SHA 未固定 / dependabot major bump 未制限)`

### 11.3 月次集計

```bash
# rework: 1 以上のラベルが付いた closed Issue を抽出
gh issue list --state closed --label "rework: 1" --search "closed:>YYYY-MM-01"
gh issue list --state closed --label "rework: 2" --search "closed:>YYYY-MM-01"
gh issue list --state closed --label "rework: 3+" --search "closed:>YYYY-MM-01"
```

`rework: 1` 以上の比率が高い場合は Issue 仕様の精度（特に Evidence of acceptance）か AI 品質に問題がある。`changes-requested-major` の指摘内容を月次で分類すると改善ポイントが見える。

---

## 12. 参考

- claude-code-action: <https://github.com/anthropics/claude-code-action>
- solutions guide: <https://github.com/anthropics/claude-code-action/blob/main/docs/solutions.md>
- gh-aw (GitHub Agentic Workflows): <https://github.github.com/gh-aw/>
- model picker changelog: <https://github.blog/changelog/2026-04-14-model-selection-for-claude-and-codex-agents-on-github-com/>

