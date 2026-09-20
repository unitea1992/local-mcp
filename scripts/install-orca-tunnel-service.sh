#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_unit="$repo_root/systemd/local-mcp-orca-tunnel.service"
target_dir="$HOME/.config/systemd/user"
target_unit="$target_dir/local-mcp-orca-tunnel.service"
profile="$HOME/.config/local-mcp/tunnel-profiles/orca-mcp.yaml"
runtime_key="$HOME/.config/local-mcp/runtime-api-key"
runtime_env="$HOME/.config/local-mcp/tunnel.env"

if [[ ! -f "$profile" ]]; then
  echo "Orca MCP profileが見つかりません: $profile"
  exit 1
fi

if [[ ! -s "$runtime_key" ]]; then
  echo "Runtime API keyが見つかりません: ~/.config/local-mcp/runtime-api-key"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jqが見つかりません。"
  exit 1
fi

tunnel_id="$(
  awk '
    $1 == "tunnel_id:" {
      gsub(/"/, "", $2)
      print $2
      exit
    }
  ' "$profile"
)"

if [[ -z "$tunnel_id" ]]; then
  echo "Orca MCP profileからTunnel IDを取得できません: $profile"
  exit 1
fi

organization_id="${CONTROL_PLANE_ORGANIZATION_ID:-}"
if [[ -z "$organization_id" ]]; then
  metadata="$(
    tunnel-client admin tunnels get "$tunnel_id" \
      --admin-key "file:$runtime_key" \
      --json
  )"
  organization_count="$(printf "%s" "$metadata" | jq '.organization_ids | length')"
  if [[ "$organization_count" -ne 1 ]]; then
    echo "Tunnelのorganization_idを一意に決められません。CONTROL_PLANE_ORGANIZATION_IDを明示してください。"
    exit 1
  fi
  organization_id="$(printf "%s" "$metadata" | jq -r '.organization_ids[0]')"
fi

install -d -m 700 "$(dirname "$runtime_env")"
printf 'CONTROL_PLANE_ORGANIZATION_ID=%s\n' "$organization_id" >"$runtime_env"
chmod 600 "$runtime_env"

mkdir -p "$target_dir"
install -m 0644 "$source_unit" "$target_unit"

# runtimes connectで起動した旧tmux runtimeが残っている場合だけ止める。
tunnel-client runtimes stop orca-mcp --json >/dev/null 2>&1 || true

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
systemctl_user enable local-mcp-orca-tunnel.service >/dev/null
systemctl_user restart local-mcp-orca-tunnel.service

echo "Orca MCP Tunnel serviceを有効化しました。"
systemctl_user --no-pager --full status local-mcp-orca-tunnel.service | sed -n '1,18p'
