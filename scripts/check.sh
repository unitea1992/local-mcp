#!/usr/bin/env bash
set -euo pipefail

bash -n scripts/*.sh

if ! command -v rumdl >/dev/null 2>&1; then
  echo "rumdl が見つかりません。" >&2
  exit 1
fi

rumdl check .

