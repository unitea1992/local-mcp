#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_unit="$repo_root/systemd/local-mcp-orca-tunnel.service"
target_dir="$HOME/.config/systemd/user"
target_unit="$target_dir/local-mcp-orca-tunnel.service"
profile="$HOME/.config/local-mcp/tunnel-profiles/orca-mcp.yaml"

if [[ ! -f "$profile" ]]; then
  echo "Orca MCP profileが見つかりません: $profile"
  exit 1
fi

if [[ ! -s "$HOME/.config/local-mcp/runtime-api-key" ]]; then
  echo "Runtime API keyが見つかりません: ~/.config/local-mcp/runtime-api-key"
  exit 1
fi

mkdir -p "$target_dir"
install -m 0644 "$source_unit" "$target_unit"

# runtimes connectで起動した旧tmux runtimeが残っている場合だけ止める。
tunnel-client runtimes stop orca-mcp --json >/dev/null 2>&1 || true

systemctl --user daemon-reload
systemctl --user enable --now local-mcp-orca-tunnel.service

echo "Orca MCP Tunnel serviceを有効化しました。"
systemctl --user --no-pager --full status local-mcp-orca-tunnel.service | sed -n '1,18p'
