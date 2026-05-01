#!/usr/bin/env bash
# security-scan.sh
# Local security scan wrapper. CI と同じ検出器をローカルで回せる。
#
# モード:
#   --staged       gitleaks: staged diff のみ（pre-commit 用）
#   --full         gitleaks: working tree 全体（デフォルト）
#   --history      gitleaks: 全 git history
#   --trivy        Trivy: fs scan（vuln + misconfig、HIGH/CRITICAL）
#   --shellcheck   shellcheck: *.sh + shebang 検出 shell ファイル（warning level）
#   --all          gitleaks(--full) + Trivy + shellcheck
#
# ツール未インストール時:
#   --staged + gitleaks 欠落 → warn + exit 0（commit ブロックしない）
#   それ以外                  → exit 2（CI=true なら exit 1）

set -eu

MODE="${1:---full}"
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

require_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi
  echo "[security-scan] $1 not installed." >&2
  echo "[security-scan]   Install: $2" >&2
  if [ "${CI:-false}" = "true" ]; then
    return 1
  fi
  return 2
}

run_gitleaks_staged() {
  if ! command -v gitleaks >/dev/null 2>&1; then
    echo "[security-scan] gitleaks not installed — skipping pre-commit secret scan." >&2
    echo "[security-scan]   Install: https://github.com/gitleaks/gitleaks#installing" >&2
    return 0
  fi
  echo "[security-scan] gitleaks: staged diff"
  gitleaks protect --staged --no-banner --redact
}

run_gitleaks_dir() {
  require_tool gitleaks https://github.com/gitleaks/gitleaks#installing || return $?
  echo "[security-scan] gitleaks: working tree"
  gitleaks dir --no-banner --redact .
}

run_gitleaks_git() {
  require_tool gitleaks https://github.com/gitleaks/gitleaks#installing || return $?
  echo "[security-scan] gitleaks: full history"
  gitleaks git --no-banner --redact .
}

run_trivy() {
  require_tool trivy https://aquasecurity.github.io/trivy/latest/getting-started/installation/ || return $?
  echo "[security-scan] trivy: fs scan (vuln+misconfig, HIGH/CRITICAL)"
  trivy fs --scanners vuln,misconfig --severity HIGH,CRITICAL --exit-code 1 --ignore-unfixed .
}

run_shellcheck() {
  require_tool shellcheck https://github.com/koalaman/shellcheck#installing || return $?
  echo "[security-scan] shellcheck: *.sh + shebang-detected shell files (warning level)"
  files=$(
    {
      find . -type f -name '*.sh' \
        -not -path './.git/*' \
        -not -path './node_modules/*' 2>/dev/null
      grep -rlE '^#!\s*(/bin/|/usr/bin/env[[:space:]]+)((ba|da|k|z)?sh)' . \
        --exclude-dir=.git \
        --exclude-dir=node_modules \
        --exclude-dir=.github 2>/dev/null || true
    } | sort -u
  )
  if [ -z "$files" ]; then
    echo "[security-scan]   no shell files found"
    return 0
  fi
  echo "$files" | xargs shellcheck -S warning
}

case "$MODE" in
  --staged)     run_gitleaks_staged ;;
  --full)       run_gitleaks_dir ;;
  --history)    run_gitleaks_git ;;
  --trivy)      run_trivy ;;
  --shellcheck) run_shellcheck ;;
  --all)
    rc=0
    run_gitleaks_dir || rc=$?
    run_trivy        || rc=$?
    run_shellcheck   || rc=$?
    exit "$rc"
    ;;
  *)
    echo "[security-scan] unknown mode: $MODE" >&2
    echo "Usage: $0 [--staged | --full | --history | --trivy | --shellcheck | --all]" >&2
    exit 2
    ;;
esac
