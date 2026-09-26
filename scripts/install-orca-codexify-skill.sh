#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/skills/orca-codexify"
target_root="$HOME/.agents/skills"
target="$target_root/orca-codexify"

mkdir -p "$target_root"

if [[ -e "$target" && ! -L "$target" ]]; then
  echo "既存の通常ファイル/ディレクトリがあるため上書きしません: $target" >&2
  exit 1
fi

ln -sfn "$source_dir" "$target"
echo "Orca Codexify skillを有効化しました: $target -> $source_dir"
