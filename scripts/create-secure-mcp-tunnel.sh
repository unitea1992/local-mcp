#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <name> <description> [scope-profile]" >&2
  exit 2
fi

name="$1"
description="$2"
scope_profile="${3:-orca-mcp}"
profile_dir="$HOME/.config/local-mcp/tunnel-profiles"
runtime_key="$HOME/.config/local-mcp/runtime-api-key"
admin_key="$HOME/.config/local-mcp/admin-api-key"
scope_profile_path="$profile_dir/$scope_profile.yaml"

for command in tunnel-client jq; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command が見つかりません。" >&2
    exit 1
  fi
done

for secret in "$runtime_key" "$admin_key"; do
  if [[ ! -s "$secret" ]]; then
    echo "必要なAPI keyが見つかりません: $secret" >&2
    exit 1
  fi
  if [[ "$(stat -Lc '%u' "$secret")" != "$(id -u)" || "$(stat -Lc '%a' "$secret")" != "600" ]]; then
    echo "API keyは現在のユーザー所有・mode 600で保存してください: $secret" >&2
    exit 1
  fi
done

if [[ ! -f "$scope_profile_path" ]]; then
  echo "scope継承元profileが見つかりません: $scope_profile_path" >&2
  exit 1
fi

scope_tunnel_id="$(
  awk '
    $1 == "tunnel_id:" {
      gsub(/"/, "", $2)
      print $2
      exit
    }
  ' "$scope_profile_path"
)"

metadata="$(
  tunnel-client admin tunnels get "$scope_tunnel_id" \
    --admin-key "file:$runtime_key" \
    --json
)"
organization_id="$(jq -r '.organization_ids[0] // empty' <<<"$metadata")"
workspace_id="$(jq -r '.workspace_ids[0] // empty' <<<"$metadata")"
if [[ -z "$organization_id" || -z "$workspace_id" ]]; then
  echo "既存TunnelからOrganization / Workspace scopeを取得できませんでした。" >&2
  exit 1
fi

existing="$(
  tunnel-client admin tunnels list \
    --admin-key "file:$admin_key" \
    --workspace-id "$workspace_id" \
    --json
)"
existing_id="$(
  jq -r --arg name "$name" '
    [.tunnels[]? | select(.name == $name) | .id][0] // empty
  ' <<<"$existing"
)"
if [[ -n "$existing_id" ]]; then
  echo "同名Tunnelが既に存在します: $existing_id" >&2
  exit 1
fi

created="$(
  tunnel-client admin tunnels create \
    --admin-key "file:$admin_key" \
    --name "$name" \
    --description "$description" \
    --organization-id "$organization_id" \
    --workspace-id "$workspace_id" \
    --json
)"
tunnel_id="$(jq -r '.id // .result.id // .tunnel.id // empty' <<<"$created")"
if [[ ! "$tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]]; then
  echo "Tunnel作成結果からTunnel IDを取得できませんでした。" >&2
  exit 1
fi

printf '%s\n' "$tunnel_id"
