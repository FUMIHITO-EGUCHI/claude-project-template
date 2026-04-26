# ADR-0002: GitHub 操作は MCP サーバーではなく `gh` CLI を使う

## Status

Accepted

## Date

2026-04-23

## Context

ADR-0001 で GitHub Issues + Projects v2 をタスク管理の single source of truth に定めた。当初は AI インターフェースとして [`github/github-mcp-server`](https://github.com/github/github-mcp-server)（MCP stdio）と `gh` CLI の併用を想定し、`.mcp.json` に `github` エントリを追加、`scripts/github-mcp-stdio.cmd` で `gh auth token` をブリッジしていた。

運用開始後、以下が分かった:

- 実作業では Claude / Codex とも `gh` CLI での issue 作成・ラベル操作が主経路になっている
- MCP 経由は利用頻度が低く、stdio server のセッション起動コストが常時発生する
- MCP のレスポンスは構造化 JSON で verbose。フィールド絞り込みができず、1 コマンドあたりのトークン消費が大きい
- `gh` CLI は `--json <fields> --jq '...'` で必要列のみ抽出でき、同一操作で数倍〜10 倍圧縮可能
- 併用は「どちらを使うべきか」の判断揺れを生み、セッション内で不整合に繋がる

要件:

- トークン消費を抑える
- 認証・権限設計を単純化する
- AI（Claude / Codex）と人間が同一コマンドで作業できる
- 将来の Projects v2 操作にも耐える

## Decision

**AI の GitHub 操作は `gh` CLI に一本化する**。MCP サーバー（`github/github-mcp-server`）は廃止。

具体対応:

- `.mcp.json` から `github` エントリを削除
- `scripts/github-mcp-stdio.cmd` を削除
- `tools/github-mcp-server/`（gitignore 済、手元バイナリ）は各自で削除可
- `SPEC.md` / `docs/handoff/README.md` / `.claude/rules/handoff.md` を `gh` CLI 記述に統一
- Chrome DevTools MCP（`.mcp.json` の `chrome-devtools` エントリ）は維持。GitHub とは別用途

代表操作の `gh` CLI 対応表:

| 操作 | `gh` CLI |
|---|---|
| タスク作成 | `gh issue create --title ... --body ... --label ...` |
| ステータス変更 | `gh issue edit <n> --add-label ... --remove-label ...` |
| Work Log 追記 | `gh issue comment <n> --body ...` |
| 担当変更 | `gh issue edit <n> --add-label 'owner: <name>'` |
| 完了申請（AI） | `gh issue edit <n> --add-label 'status: ready-for-close'` + `gh issue comment ...` |
| close（人間のみ） | `gh issue close <n>` |
| 検索 | `gh issue list --search ... --json number,title,labels` |
| Projects v2 | `gh project ...` / 複雑ケースは `gh api graphql` |

## Alternatives Considered

### A. MCP と `gh` CLI の併用（現状維持）

- Pros: 構造化アクセスと CLI を使い分けられる
- Cons: トークン消費（MCP レスポンス）、起動コスト、判断揺れ、設定メンテ 2 系統
- **Rejected**: メリットが実利用で活きていない

### B. MCP のみ

- Pros: すべて構造化 JSON、型安全
- Cons: 出力制御ができず大きいレスポンスを毎回払う。CLI を知っている人間と AI の経路が乖離
- **Rejected**: トークン観点で最悪

### C. `gh api graphql` を主として自前ラッパーを書く

- Pros: 最小権限・最小レスポンスで構築可能
- Cons: 保守対象が増える。`gh issue` で十分な操作がほとんど
- **Rejected**: オーバーエンジニアリング

### D. `gh` CLI のみ（採用）

- Pros: 単一経路、認証も `gh auth` で統一、出力圧縮容易
- Cons: Projects v2 の一部操作は `gh api graphql` 経由が必要
- **Accepted**: 弱点は代替手段で吸収可能、運用コストが最も低い

## Consequences

### Positive

- MCP サーバー起動コストがゼロに
- レスポンスサイズを `--json` + `--jq` で精密制御できる
- 設定が `.mcp.json` の chrome-devtools 1 系統のみになり管理が単純化
- 人間・Claude・Codex が同じコマンドセットで作業でき、ナレッジ共有が容易
- `scripts/github-mcp-stdio.cmd` のようなブリッジスクリプトを保守しなくて良い

### Negative / Trade-offs

- Projects v2 の細かい Field 操作が必要になった時は `gh api graphql` を書く必要がある
- 構造化されたツールスキーマが無いぶん、AI 側で JSON 出力のパースをケースバイケースで組む必要

### Migration

- `.mcp.json` から `github` エントリ削除
- `scripts/github-mcp-stdio.cmd` を `git rm`
- ドキュメント（SPEC.md / handoff guides）を `gh` CLI 記述に統一
- ADR-0001 の Decision 節「AI interface」項目は本 ADR で上書きされる（0001 自体は supersede しない。インターフェース選択は独立 scope）
