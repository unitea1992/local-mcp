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
codexify_config="${CODEXIFY_CONFIG:-$HOME/.codexify/codexify.config.json}"
launcher="$HOME/.local/bin/alinavigator-mcp"
probe_launcher="$HOME/.local/bin/alinavigator-mcp-probe"

[[ "$tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]] || { echo "Tunnel IDの形式が不正です: $tunnel_id" >&2; exit 1; }
for command in tunnel-client jq; do command -v "$command" >/dev/null 2>&1 || { echo "$command が見つかりません。" >&2; exit 1; }; done
[[ -s "$runtime_key" ]] || { echo "Runtime API keyが見つかりません。" >&2; exit 1; }
[[ -f "$codexify_config" ]] || { echo "Codexify configが見つかりません: $codexify_config" >&2; exit 1; }
[[ -x "$launcher" ]] || { echo "AliNavigator MCP launcherが見つかりません。" >&2; exit 1; }
[[ -x "$probe_launcher" ]] || { echo "AliNavigator MCP probeが見つかりません。" >&2; exit 1; }
[[ -s "$credentials_env" ]] || { echo "AliNavigator Gateway資格情報が見つかりません。" >&2; exit 1; }
[[ "$(stat -Lc '%u' "$credentials_env")" == "$(id -u)" && "$(stat -Lc '%a' "$credentials_env")" == "600" ]] || { echo "AliNavigator Gateway資格情報は現在のユーザー所有・mode 600で保存してください。" >&2; exit 1; }
"$probe_launcher" >/dev/null 2>&1 || { echo "AliNavigator MCPのstdio/tools probeに失敗しました。" >&2; exit 1; }

hub_tunnel_id="$(jq -r '.openaiTunnel.tunnelId // .openaiTunnels[0].tunnelId // empty' "$codexify_config")"
[[ "$hub_tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]] || { echo "Codexify Tunnel IDを取得できませんでした。" >&2; exit 1; }

hub_metadata="$(tunnel-client admin tunnels get "$hub_tunnel_id" --admin-key "file:$runtime_key" --json)"
target_metadata="$(tunnel-client admin tunnels get "$tunnel_id" --admin-key "file:$runtime_key" --json)"
organization_id="$(jq -r '.organization_ids[0] // empty' <<<"$hub_metadata")"
[[ "$organization_id" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "Codexify TunnelのOrganizationを取得できませんでした。" >&2; exit 1; }

jq -e --arg org "$organization_id" '.organization_ids | index($org) != null' >/dev/null <<<"$target_metadata" || { echo "AliNavigator TunnelがCodexify Tunnelと同じOrganizationに属していません。" >&2; exit 1; }
hub_workspaces="$(jq -c '.workspace_ids' <<<"$hub_metadata")"
jq -e --argjson hubs "$hub_workspaces" '[.workspace_ids[] as $candidate | select($hubs | index($candidate) != null)] | length > 0' >/dev/null <<<"$target_metadata" || { echo "AliNavigator TunnelがCodexify Tunnelと同じChatGPT Workspaceに関連付けられていません。" >&2; exit 1; }

install -d -m 700 "$HOME/.config/local-mcp" "$profile_dir"
printf 'CONTROL_PLANE_ORGANIZATION_ID=%s\n' "$organization_id" > "$runtime_env"
chmod 600 "$runtime_env"

if [[ -f "$profile" ]]; then
  current_tunnel_id="$(awk '$1 == "tunnel_id:" {gsub(/"/, "", $2); print $2; exit}' "$profile")"
  [[ "$current_tunnel_id" == "$tunnel_id" ]] || { echo "既存profileは別Tunnelを参照しています: $current_tunnel_id" >&2; exit 1; }
fi

tunnel-client init --force --profile alinavigator-mcp --profile-dir "$profile_dir" --tunnel-id "$tunnel_id" --control-plane-api-key-ref "file:$runtime_key" --mcp-command "$launcher" --health-listen-addr 127.0.0.1:0
"$(cd "$(dirname "$0")" && pwd)/install-alinavigator-tunnel-service.sh"
