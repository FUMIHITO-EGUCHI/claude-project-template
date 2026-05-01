# Security Policy

## Reporting a Vulnerability

このテンプレ自体（workflow / scripts / hooks）に脆弱性を見つけた場合:

- **公開 Issue にしない**
- GitHub の [Private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) を使うか、リポジトリ所有者へ直接連絡

返信は best-effort（個人メンテ、SLA なし）。

## Scope

対象:

- `.github/workflows/` の権限設定・secret 取り扱い
- `scripts/` の hook / init 処理
- テンプレ展開時に外部利用者へ伝播する設定

対象外:

- このテンプレを使って作られた派生プロジェクトの脆弱性（派生先で報告先を設定）
- `docs/` の記述ミス（通常 Issue で OK）

## Secrets

このテンプレは以下の secret を想定する。値は各利用者が自分の repo に設定する:

- `CLAUDE_CODE_OAUTH_TOKEN` — `/install-github-app` で自動登録
- `GITHUB_TOKEN` — Actions 既定

テンプレ自体には secret を含めない。
