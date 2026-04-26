---
paths:
  - "**/*"
---

# Shell encoding rule (Windows)

Windows 環境で日本語を含むファイル読み書き / 外部コマンド実行時に守る。

## Do

- 日本語 I/O は **Bash tool から `pwsh -NoProfile -Command '...'` 経由で PowerShell 7 を呼ぶ**
- `Get-Content` を使うなら `-Encoding UTF8` を明示するか、PS7 上で実行する
- 書き込みは `[System.IO.File]::WriteAllText(path, text, (New-Object System.Text.UTF8Encoding($false)))` か PS7 の `Set-Content -Encoding utf8`
- 文字化けして見えたらまず `Format-Hex` または Node / .NET の UTF-8 読みで実体を確認してから修復判断する

## Don't

- harness の PowerShell tool（Windows PowerShell 5.1 固定）を日本語 I/O に使わない
- `Get-Content` 既定読込（エンコーディング未指定）で UTF-8 no-BOM を扱わない
- 日本語を heredoc / stdin 経由で外部コマンド（Node 等）へ流さない。ファイル経由か JSON body を使う
- `Set-Content` 既定書込（エンコーディング未指定）に依存しない

## Background

Windows PowerShell 5.1 の既定エンコーディングは CP932 寄りで、UTF-8 no-BOM を誤読・誤記する。PowerShell 7 は既定で UTF-8。
