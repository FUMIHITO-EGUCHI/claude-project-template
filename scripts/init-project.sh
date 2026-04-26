#!/usr/bin/env bash
# init-project.sh
# template repo を新規 PJ として展開した直後に 1 回だけ実行する。
# 冪等。再実行しても安全（既に置換済みのプレースホルダはスキップ）。
#
# やること:
#   1. プロジェクト名・概要を対話 or 引数で受け取り、CLAUDE.md / AGENTS.md / README.md / package.json を置換
#   2. git hooks をインストール（commit-msg + pre-commit）
#   3. ラベルを GitHub に同期（gh label create --force）
#   4. 残った <!-- @stack:replace --> ブロックを警告
#
# 使い方:
#   sh scripts/init-project.sh
#   sh scripts/init-project.sh "my-project" "短い説明"

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

PROJECT_NAME="${1:-}"
PROJECT_DESC="${2:-}"

if [ -z "$PROJECT_NAME" ]; then
  printf "Project name (e.g. my-cool-app): "
  read -r PROJECT_NAME
fi
if [ -z "$PROJECT_NAME" ]; then
  echo "[init] project name is required" >&2
  exit 1
fi

if [ -z "$PROJECT_DESC" ]; then
  printf "Short description: "
  read -r PROJECT_DESC
fi

echo ""
echo "[init] project name: $PROJECT_NAME"
echo "[init] description : $PROJECT_DESC"
echo ""

# ---- 1. プレースホルダ置換 ----
# 対象: CLAUDE.md / AGENTS.md / README.md / package.json
# placeholder: <!-- @project:name --> と <!-- @project:description --> と PROJECT_NAME_PLACEHOLDER

replace_in() {
  local file="$1"
  [ -f "$file" ] || return 0
  node -e "
    const fs = require('fs');
    const path = process.argv[1];
    const name = process.argv[2];
    const desc = process.argv[3];
    let s = fs.readFileSync(path, 'utf8');
    s = s.replaceAll('<!-- @project:name -->', name);
    s = s.replaceAll('<!-- @project:description -->', desc);
    s = s.replaceAll('PROJECT_NAME_PLACEHOLDER', name);
    fs.writeFileSync(path, s);
  " "$file" "$PROJECT_NAME" "$PROJECT_DESC"
  echo "  patched: $file"
}

echo "[init] replacing placeholders..."
replace_in CLAUDE.md
replace_in AGENTS.md
replace_in README.md
replace_in package.json
echo ""

# ---- 2. hooks インストール ----
echo "[init] installing git hooks..."
sh scripts/setup-hooks.sh
echo ""

# ---- 3. ラベル同期 ----
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo "[init] syncing GitHub labels..."
    if node scripts/sync-labels.mjs; then
      echo ""
    else
      echo "[init] label sync failed (continuing). Run 'node scripts/sync-labels.mjs' manually after fixing." >&2
      echo ""
    fi
  else
    echo "[init] gh not authenticated — skipping label sync. Run 'gh auth login' then 'node scripts/sync-labels.mjs'." >&2
    echo ""
  fi
else
  echo "[init] gh CLI not found — skipping label sync." >&2
  echo ""
fi

# ---- 4. 残留プレースホルダ警告 ----
# ADR / README / scripts は規約説明として @stack:replace を含むので除外
echo "[init] scanning for remaining @stack:replace blocks..."
remaining=$(grep -rln '<!-- @stack:replace -->' \
    --include='*.md' --include='*.json' --include='*.yml' . 2>/dev/null \
  | grep -v -E '(^\./README\.md$|^\./docs/decisions/|/node_modules/|/\.git/|^\./scripts/)' \
  || true)
if [ -n "$remaining" ]; then
  echo ""
  echo "  Edit these files to fill in stack-specific sections:"
  echo "$remaining" | sed 's/^/    /'
  echo ""
fi

echo "[init] done."
echo ""
echo "Next:"
echo "  1. Edit @stack:replace blocks listed above"
echo "  2. Customize .github/labels.yml (especially area: labels)"
echo "  3. Create your GitHub Projects v2 board (Todo / In Progress / Blocked / Ready for Close / Done)"
echo "  4. Delete this script when you no longer need it: rm scripts/init-project.sh"
