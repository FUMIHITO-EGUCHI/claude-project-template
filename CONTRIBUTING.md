# Contributing

個人メンテのテンプレ。受付方針は控えめ。

## 歓迎

- **Bug report** — Issue でどうぞ。再現手順と環境を明記
- **ドキュメント改善** — typo / リンク切れ / 説明不足は PR 直接 OK
- **質問・議論** — Discussions または Issue（`type: investigation`）

## 要相談

- **新機能・workflow 追加** — 先に Issue を立てて方向性合意してから PR
- **既存設計の変更**（ADR-0001〜0003 に関わる範囲）— 新規 ADR を `docs/decisions/` に追加して提案

無相談の大型 PR は close することがある。

## ローカル開発

```sh
# hooks インストール（commit-msg + pre-commit）
sh scripts/setup-hooks.sh

# ラベル定義の検証
node scripts/sync-labels.mjs --dry-run
```

## Commit message

このテンプレ自身の変更は `[skip-issue]` で OK（Issue 駆動を強制しない）。
派生プロジェクトでは `#<issue>` 必須（commit-msg hook が enforce）。

## License

contribute された変更は MIT License で配布される（[LICENSE](LICENSE)）。
