#!/usr/bin/env bash
# sync-labels.sh
# .github/labels.yml の内容を gh CLI で repo に同期する。
#
# 使い方:
#   bash scripts/sync-labels.sh                # 現リポへ
#   GH_REPO=owner/name bash scripts/sync-labels.sh
#
# 動作:
#   - labels.yml に定義されているラベルを `gh label create --force` で create-or-update
#   - labels.yml にないラベルは削除しない（手動で追加したラベルが消えないようにする）
#
# 依存: gh, node

set -euo pipefail
node scripts/sync-labels.mjs
