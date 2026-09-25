#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_unit="$repo_root/systemd/local-mcp-alinavigator-tunnel.service"
target_dir="$HOME/.config/systemd/user"
target_unit="$target_dir/local-mcp-alinavigator-tunnel.service"
profile="$HOME/.config/local-mcp/tunnel-profiles/alinavigator-mcp.yaml"
runtime_key="$HOME/.config/local-mcp/runtime-api-key"
runtime_env="$HOME/.config/local-mcp/tunnel.env"
credentials_env="$HOME/.config/local-mcp/alinavigator.env"
launcher="$HOME/.local/bin/alinavigator-mcp"
probe_launcher="$HOME/.local/bin/alinavigator-mcp-probe"

if [[ ! -f "$profile" ]]; then
  echo "AliNavigator MCP profileが見つかりません: $profile"
  exit 1
fi

if [[ ! -s "$runtime_key" ]]; then
  echo "Runtime API keyが見つかりません: ~/.config/local-mcp/runtime-api-key"
  exit 1
fi

if [[ ! -s "$runtime_env" ]]; then
  echo "Tunnel organization contextが見つかりません: ~/.config/local-mcp/tunnel.env"
  exit 1
fi

if [[ ! -s "$credentials_env" ]]; then
  echo "AliNavigator Gateway資格情報が見つかりません: ~/.config/local-mcp/alinavigator.env"
  exit 1
fi
if [[ "$(stat -Lc '%u' "$credentials_env")" != "$(id -u)" || "$(stat -Lc '%a' "$credentials_env")" != "600" ]]; then
  echo "AliNavigator Gateway資格情報は現在のユーザー所有・mode 600で保存してください。"
  exit 1
fi

if [[ ! -x "$launcher" ]]; then
  echo "AliNavigator MCP launcherが見つかりません: ~/.local/bin/alinavigator-mcp"
  exit 1
fi
if [[ ! -x "$probe_launcher" ]]; then
  echo "AliNavigator MCP probeが見つかりません: ~/.local/bin/alinavigator-mcp-probe"
  exit 1
fi
if ! "$probe_launcher" >/dev/null 2>&1; then
  echo "AliNavigator MCPのstdio/tools probeに失敗しました。"
  exit 1
fi

mkdir -p "$target_dir"
install -m 0644 "$source_unit" "$target_unit"

tunnel-client runtimes stop alinavigator-mcp --json >/dev/null 2>&1 || true

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
systemctl_user enable local-mcp-alinavigator-tunnel.service >/dev/null
systemctl_user restart local-mcp-alinavigator-tunnel.service

echo "AliNavigator MCP Tunnel serviceを有効化しました。"
systemctl_user --no-pager --full status local-mcp-alinavigator-tunnel.service | sed -n '1,18p'
