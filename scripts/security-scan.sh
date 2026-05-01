#!/usr/bin/env bash
# security-scan.sh
# ローカル security scan ラッパー。CI と同じ検出器をローカルでも回せる。
#
# モード:
#   --staged    staged diff のみ scan（pre-commit hook 用）
#   --full      working tree 全体 scan（手動確認用、デフォルト）
#   --history   git history 全 commit scan（公開前確認用、重い）
#
# 動作:
#   - gitleaks がインストールされていれば実行
#   - 未インストール時:
#       * pre-commit (--staged) → warn のみ、exit 0（commit ブロックしない）
#       * それ以外           → エラー終了 exit 2（CI と人間用）
#   - leak 検出時は exit 1
#
# CI 環境（$CI=true）では未インストールも exit 1。

set -eu

MODE="${1:---full}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

if ! command -v gitleaks >/dev/null 2>&1; then
  case "$MODE" in
    --staged)
      echo "[security-scan] gitleaks not installed — skipping pre-commit secret scan." >&2
      echo "[security-scan]   Install: https://github.com/gitleaks/gitleaks#installing" >&2
      exit 0
      ;;
    *)
      echo "[security-scan] gitleaks not installed." >&2
      echo "[security-scan]   Install: https://github.com/gitleaks/gitleaks#installing" >&2
      [ "${CI:-false}" = "true" ] && exit 1
      exit 2
      ;;
  esac
fi

case "$MODE" in
  --staged)
    echo "[security-scan] gitleaks: staged diff scan"
    gitleaks protect --staged --no-banner --redact
    ;;
  --full)
    echo "[security-scan] gitleaks: working tree scan"
    gitleaks dir --no-banner --redact .
    ;;
  --history)
    echo "[security-scan] gitleaks: full git history scan"
    gitleaks git --no-banner --redact .
    ;;
  *)
    echo "[security-scan] unknown mode: $MODE" >&2
    echo "Usage: $0 [--staged | --full | --history]" >&2
    exit 2
    ;;
esac
