#!/bin/sh
# setup-hooks.sh
# git hooks を .git/hooks/ にインストールする。
# clone 後や hooks を再インストールしたいときに実行する。
#
# 使い方: sh scripts/setup-hooks.sh

set -e

HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
SCRIPTS_DIR="$(dirname "$0")"

install_hook() {
  name="$1"
  src="$SCRIPTS_DIR/$name"
  dst="$HOOKS_DIR/$name"

  if [ ! -f "$src" ]; then
    echo "Hook source not found: $src"
    exit 1
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  echo "Installed: $dst"
}

install_hook "pre-commit"
install_hook "commit-msg"

echo "Git hooks installed successfully."
