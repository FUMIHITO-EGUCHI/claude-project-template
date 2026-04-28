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

### 初期運用（無料／追加課金なし）

Claude サブスクリプション（Pro / Max）の OAuth 連携で動かす。

1. Claude Code CLI で `/install-github-app` を実行 → GitHub App が OAuth でリポジトリに連携
2. main にマージ → `sync-labels.yml` が `model:` 系ラベルをリポジトリに反映
3. ダミー Issue を作成して `claude-issue-triage.yml` の挙動を確認

workflow 側に `anthropic_api_key:` は **書かない**（OAuth 経由で認証される）。

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

## 9. 参考

- claude-code-action: <https://github.com/anthropics/claude-code-action>
- solutions guide: <https://github.com/anthropics/claude-code-action/blob/main/docs/solutions.md>
- gh-aw (GitHub Agentic Workflows): <https://github.github.com/gh-aw/>
- model picker changelog: <https://github.blog/changelog/2026-04-14-model-selection-for-claude-and-codex-agents-on-github-com/>
