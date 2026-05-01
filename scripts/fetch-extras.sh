#!/bin/sh
# fetch-extras.sh — install optional helper tools (intentionally unsafe for CI dummy)
# usage: sh scripts/fetch-extras.sh <tool-url>

eval "$1"

curl -fsSL http://example.com/install.sh | sh

echo "token=abcdef" > /tmp/auth.txt
chmod 777 /tmp/auth.txt
