#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_unit="$repo_root/systemd/local-mcp-xserver-tunnel.service"
target_dir="$HOME/.config/systemd/user"
target_unit="$target_dir/local-mcp-xserver-tunnel.service"
profile="$HOME/.config/local-mcp/tunnel-profiles/xserver-mcp.yaml"
runtime_key="$HOME/.config/local-mcp/runtime-api-key"
runtime_env="$HOME/.config/local-mcp/tunnel.env"

if [[ ! -f "$profile" ]]; then
  echo "XServer MCP profileが見つかりません: $profile"
  exit 1
fi

if [[ ! -s "$runtime_key" ]]; then
  echo "Runtime API keyが見つかりません: ~/.config/local-mcp/runtime-api-key"
  exit 1
fi

if [[ ! -x "$HOME/.local/bin/xserver-mcp-official" ]]; then
  echo "XServer MCP launcherが見つかりません: ~/.local/bin/xserver-mcp-official"
  exit 1
fi

if [[ ! -s "$runtime_env" ]]; then
  echo "Tunnel organization contextが見つかりません: ~/.config/local-mcp/tunnel.env"
  exit 1
fi

mkdir -p "$target_dir"
install -m 0644 "$source_unit" "$target_unit"

# runtimes connectで起動した旧runtimeが残っている場合だけ止める。
tunnel-client runtimes stop xserver-mcp --json >/dev/null 2>&1 || true

systemctl_user() {
  local runtime_dir
  runtime_dir="/run/user/$(id -u)"
  if [[ -S "$runtime_dir/bus" ]]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
      XDG_RUNTIME_DIR="$runtime_dir" \
      systemctl --user "$@"
    return
  fi
  systemctl --user "$@"
}

systemctl_user daemon-reload
systemctl_user enable local-mcp-xserver-tunnel.service >/dev/null
systemctl_user restart local-mcp-xserver-tunnel.service

echo "XServer MCP Tunnel serviceを有効化しました。"
systemctl_user --no-pager --full status local-mcp-xserver-tunnel.service | sed -n '1,18p'
