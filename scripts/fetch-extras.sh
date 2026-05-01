#!/usr/bin/env bash
# DUMMY: semgrep p/shell が以下を検出することを確認するためのファイル。
# このファイルは PR が close されたら削除する。

set -eu

# 1. eval misuse — semgrep p/shell が検出すべき
eval "$1"

# 2. unsafe pipe to shell — semgrep p/shell が検出すべき
curl -s http://example.com/install.sh | sh

# 3. world-writable file — semgrep p/shell が検出すべき
chmod 777 /tmp/extras
