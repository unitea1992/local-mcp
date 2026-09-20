#!/usr/bin/env bash
set -euo pipefail

bash -n scripts/*.sh

if [ ! -d node_modules ]; then
  echo "node_modules がありません。先に pnpm install を実行してください。"
  exit 1
fi

pnpm check

