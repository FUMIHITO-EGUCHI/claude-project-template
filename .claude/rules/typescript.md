---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Rules

- `tsconfig.json` の `strict` を崩さない
- `any` は原則使わない。必要なら理由が説明できる箇所に限定し、まず `unknown` と型絞り込みを検討する
- boxed type は使わない。`String` / `Number` / `Boolean` ではなく `string` / `number` / `boolean`
- 型定義を後回しにしない。永続化データ、runtime message、表示用データは分けて持つ
- DOM や外部入力から得た不安定な値は、そのまま内部型へ流さず、変換関数か型ガードを通す
- 型アサーションは最小限にする。使うなら、なぜ安全かをコード上で説明できる状態にする
- 型定義は `src/types/` または責務ごとの `*.types.ts` に整理する
- 汎用 utility とドメイン依存処理を混在させない
