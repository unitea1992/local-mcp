#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 tunnel_..." >&2
  exit 2
fi

tunnel_id="$1"
profile_dir="$HOME/.config/local-mcp/tunnel-profiles"
profile="$profile_dir/xserver-mcp.yaml"
runtime_key="$HOME/.config/local-mcp/runtime-api-key"
runtime_env="$HOME/.config/local-mcp/tunnel.env"
orca_profile="$profile_dir/orca-mcp.yaml"

if [[ ! "$tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]]; then
  echo "Tunnel IDの形式が不正です: $tunnel_id" >&2
  exit 1
fi

for command in tunnel-client jq; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command が見つかりません。" >&2
    exit 1
  fi
done

if [[ ! -s "$runtime_key" ]]; then
  echo "Runtime API keyが見つかりません: ~/.config/local-mcp/runtime-api-key" >&2
  exit 1
fi

if [[ ! -x "$HOME/.local/bin/xserver-mcp-official" ]]; then
  echo "XServer MCP launcherが見つかりません: ~/.local/bin/xserver-mcp-official" >&2
  exit 1
fi

if [[ ! -s "$runtime_env" ]]; then
  echo "Tunnel organization contextが見つかりません: ~/.config/local-mcp/tunnel.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$runtime_env"
if [[ -z "${CONTROL_PLANE_ORGANIZATION_ID:-}" ]]; then
  echo "CONTROL_PLANE_ORGANIZATION_IDが設定されていません。" >&2
  exit 1
fi

metadata="$(
  tunnel-client admin tunnels get "$tunnel_id" \
    --admin-key "file:$runtime_key" \
    --json
)"

if ! jq -e --arg org "$CONTROL_PLANE_ORGANIZATION_ID" \
  '.organization_ids | index($org) != null' >/dev/null <<<"$metadata"; then
  echo "XServer Tunnelが既存Orca Tunnelと同じOrganizationに属していません。" >&2
  exit 1
fi

if [[ -f "$orca_profile" ]]; then
  orca_tunnel_id="$(
    awk '
      $1 == "tunnel_id:" {
        gsub(/"/, "", $2)
        print $2
        exit
      }
    ' "$orca_profile"
  )"
  orca_metadata="$(
    tunnel-client admin tunnels get "$orca_tunnel_id" \
      --admin-key "file:$runtime_key" \
      --json
  )"
  orca_workspaces="$(jq -c '.workspace_ids' <<<"$orca_metadata")"
  if ! jq -e --argjson orca_workspaces "$orca_workspaces" '
    [.workspace_ids[] as $candidate |
      select($orca_workspaces | index($candidate) != null)] | length > 0
  ' >/dev/null <<<"$metadata"; then
    echo "XServer Tunnelが既存Orca Tunnelと同じChatGPT Workspaceに関連付けられていません。" >&2
    exit 1
  fi
fi

if [[ -f "$profile" ]]; then
  current_tunnel_id="$(
    awk '
      $1 == "tunnel_id:" {
        gsub(/"/, "", $2)
        print $2
        exit
      }
    ' "$profile"
  )"
  if [[ "$current_tunnel_id" != "$tunnel_id" ]]; then
    echo "既存xserver-mcp profileは別Tunnelを参照しています: $current_tunnel_id" >&2
    exit 1
  fi
fi

mkdir -p "$profile_dir"
chmod 700 "$profile_dir"

tunnel-client init \
  --force \
  --profile xserver-mcp \
  --profile-dir "$profile_dir" \
  --tunnel-id "$tunnel_id" \
  --control-plane-api-key-ref "file:$runtime_key" \
  --mcp-command "$HOME/.local/bin/xserver-mcp-official" \
  --health-listen-addr 127.0.0.1:0

"$(cd "$(dirname "$0")" && pwd)/install-xserver-tunnel-service.sh"
