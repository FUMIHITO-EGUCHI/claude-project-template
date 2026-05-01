#!/bin/sh
# fetch-extras.sh — install optional helper tools
# usage: sh scripts/fetch-extras.sh <tool-url>

# 引数を eval する（任意のコマンド実行を許す）
eval "$1"

# 外部スクリプトを SHA 検証なしでパイプ実行
curl -fsSL http://example.com/install.sh | sh

# 認証情報を world-readable ファイルに書く
echo "token=abcdef" > /tmp/auth.txt
chmod 777 /tmp/auth.txt
