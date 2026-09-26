#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <name> <description> [scope-tunnel-id]" >&2
  exit 2
fi

name="$1"
description="$2"
scope_tunnel_id="${3:-}"
runtime_key="$HOME/.config/local-mcp/runtime-api-key"
admin_key="$HOME/.config/local-mcp/admin-api-key"
codexify_config="${CODEXIFY_CONFIG:-$HOME/.codexify/codexify.config.json}"

for command in tunnel-client jq; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command が見つかりません。" >&2; exit 1; }
done

for secret in "$runtime_key" "$admin_key"; do
  [[ -s "$secret" ]] || { echo "必要なAPI keyが見つかりません: $secret" >&2; exit 1; }
  [[ "$(stat -Lc '%u' "$secret")" == "$(id -u)" && "$(stat -Lc '%a' "$secret")" == "600" ]] || {
    echo "API keyは現在のユーザー所有・mode 600で保存してください: $secret" >&2
    exit 1
  }
done

if [[ -z "$scope_tunnel_id" ]]; then
  [[ -f "$codexify_config" ]] || { echo "Codexify configが見つかりません: $codexify_config" >&2; exit 1; }
  scope_tunnel_id="$(jq -r '.openaiTunnel.tunnelId // .openaiTunnels[0].tunnelId // empty' "$codexify_config")"
fi

[[ "$scope_tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]] || { echo "scope Tunnel IDを取得できませんでした。" >&2; exit 1; }

metadata="$(tunnel-client admin tunnels get "$scope_tunnel_id" --admin-key "file:$runtime_key" --json)"
organization_id="$(jq -r '.organization_ids[0] // empty' <<<"$metadata")"
workspace_id="$(jq -r '.workspace_ids[0] // empty' <<<"$metadata")"
[[ -n "$organization_id" && -n "$workspace_id" ]] || { echo "scope TunnelからOrganization / Workspaceを取得できませんでした。" >&2; exit 1; }

existing="$(tunnel-client admin tunnels list --admin-key "file:$admin_key" --workspace-id "$workspace_id" --json)"
existing_id="$(jq -r --arg name "$name" '[.tunnels[]? | select(.name == $name) | .id][0] // empty' <<<"$existing")"
[[ -z "$existing_id" ]] || { echo "同名Tunnelが既に存在します: $existing_id" >&2; exit 1; }

created="$(tunnel-client admin tunnels create --admin-key "file:$admin_key" --name "$name" --description "$description" --organization-id "$organization_id" --workspace-id "$workspace_id" --json)"
tunnel_id="$(jq -r '.id // .result.id // .tunnel.id // empty' <<<"$created")"
[[ "$tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]] || { echo "Tunnel作成結果からTunnel IDを取得できませんでした。" >&2; exit 1; }
printf '%s\n' "$tunnel_id"
