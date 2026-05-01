#!/usr/bin/env bash
# DUMMY: semgrep r/bash の curl-pipe-bash 検出確認用。
# このファイルは PR が close されたら削除する。

set -eu

# r/bash curl-pipe-bash が検出すべきパターン
curl -s http://example.com/install.sh | sh

# r/bash curl-eval が検出すべきパターン (curl 出力を eval)
eval "$(curl -s http://example.com/setup.sh)"
