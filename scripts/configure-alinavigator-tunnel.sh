#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 tunnel_..." >&2
  exit 2
fi

tunnel_id="$1"
profile_dir="$HOME/.config/local-mcp/tunnel-profiles"
profile="$profile_dir/alinavigator-mcp.yaml"
runtime_key="$HOME/.config/local-mcp/runtime-api-key"
runtime_env="$HOME/.config/local-mcp/tunnel.env"
credentials_env="$HOME/.config/local-mcp/alinavigator.env"
orca_profile="$profile_dir/orca-mcp.yaml"
launcher="$HOME/.local/bin/alinavigator-mcp"
probe_launcher="$HOME/.local/bin/alinavigator-mcp-probe"

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

if [[ ! -x "$launcher" ]]; then
  echo "AliNavigator MCP launcherが見つかりません: ~/.local/bin/alinavigator-mcp" >&2
  echo "先に alinavigator-api で ./mcp/scripts/install-local.sh を実行してください。" >&2
  exit 1
fi

if [[ ! -s "$credentials_env" ]]; then
  echo "AliNavigator Gateway資格情報が見つかりません: ~/.config/local-mcp/alinavigator.env" >&2
  exit 1
fi
if [[ "$(stat -Lc '%u' "$credentials_env")" != "$(id -u)" || "$(stat -Lc '%a' "$credentials_env")" != "600" ]]; then
  echo "AliNavigator Gateway資格情報は現在のユーザー所有・mode 600で保存してください。" >&2
  exit 1
fi
if [[ ! -x "$probe_launcher" ]]; then
  echo "AliNavigator MCP probeが見つかりません: ~/.local/bin/alinavigator-mcp-probe" >&2
  exit 1
fi
if ! "$probe_launcher" >/dev/null 2>&1; then
  echo "AliNavigator MCPのstdio/tools probeに失敗しました。" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$credentials_env"
set +a
if [[ -z "${ALINAVIGATOR_ACCESS_CLIENT_ID:-}" || -z "${ALINAVIGATOR_ACCESS_CLIENT_SECRET:-}" ]]; then
  echo "alinavigator.env に必要なGateway Access資格情報がありません。" >&2
  exit 1
fi
unset ALINAVIGATOR_ACCESS_CLIENT_ID ALINAVIGATOR_ACCESS_CLIENT_SECRET

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
  echo "AliNavigator Tunnelが既存Orca Tunnelと同じOrganizationに属していません。" >&2
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
    echo "AliNavigator Tunnelが既存Orca Tunnelと同じChatGPT Workspaceに関連付けられていません。" >&2
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
    echo "既存alinavigator-mcp profileは別Tunnelを参照しています: $current_tunnel_id" >&2
    exit 1
  fi
fi

mkdir -p "$profile_dir"
chmod 700 "$profile_dir"

tunnel-client init \
  --force \
  --profile alinavigator-mcp \
  --profile-dir "$profile_dir" \
  --tunnel-id "$tunnel_id" \
  --control-plane-api-key-ref "file:$runtime_key" \
  --mcp-command "$launcher" \
  --health-listen-addr 127.0.0.1:0

"$(cd "$(dirname "$0")" && pwd)/install-alinavigator-tunnel-service.sh"
