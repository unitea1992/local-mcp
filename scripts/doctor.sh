#!/usr/bin/env bash
set -u

PROFILE_DIR="${LOCAL_MCP_PROFILE_DIR:-$HOME/.config/local-mcp/tunnel-profiles}"
ADMIN_KEY="$HOME/.config/local-mcp/admin-api-key"
RUNTIME_KEY="$HOME/.config/local-mcp/runtime-api-key"
ALI_ENV="$HOME/.config/local-mcp/alinavigator.env"
CODEXIFY_CONFIG="${CODEXIFY_CONFIG:-$HOME/.codexify/codexify.config.json}"
CODEXIFY_BIN="${CODEXIFY_BIN:-}"
failed=0

if [[ -z "$CODEXIFY_BIN" ]]; then
  if command -v codexify >/dev/null 2>&1; then
    CODEXIFY_BIN="$(command -v codexify)"
  else
    CODEXIFY_BIN="$HOME/.codexify/bin/codexify"
  fi
fi

systemctl_user() {
  local runtime_dir
  runtime_dir="/run/user/$(id -u)"
  if [[ -S "$runtime_dir/bus" ]]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" XDG_RUNTIME_DIR="$runtime_dir" systemctl --user "$@"
    return
  fi
  systemctl --user "$@"
}

echo "== local-mcp doctor =="
echo

echo "-- Codexify --"
if [[ -x "$CODEXIFY_BIN" ]]; then
  if "$CODEXIFY_BIN" --config "$CODEXIFY_CONFIG" doctor; then
    :
  else
    failed=1
  fi
else
  echo "Codexify: not installed"
  failed=1
fi

echo
echo "-- Orca --"
if command -v orca-ide >/dev/null 2>&1 && orca-ide status --json >/dev/null 2>&1; then
  echo "Orca CLI/runtime: OK"
else
  echo "Orca CLI/runtime: NG"
  failed=1
fi

skill="$HOME/.agents/skills/orca-codexify"
if [[ -L "$skill" && -f "$skill/SKILL.md" ]]; then
  echo "Orca Codexify skill: OK"
else
  echo "Orca Codexify skill: missing (run ./scripts/install-orca-codexify-skill.sh)"
  failed=1
fi

echo
echo "-- AliNavigator Tunnel --"
if [[ ! -s "$RUNTIME_KEY" ]]; then
  echo "Runtime API key: missing"
  failed=1
elif [[ "$(stat -Lc '%u' "$RUNTIME_KEY")" != "$(id -u)" || "$(stat -Lc '%a' "$RUNTIME_KEY")" != "600" ]]; then
  echo "Runtime API key: unsafe permissions"
  failed=1
else
  echo "Runtime API key: permissions OK"
fi

if [[ ! -s "$ALI_ENV" ]]; then
  echo "AliNavigator Gateway資格情報: missing"
  failed=1
elif [[ "$(stat -Lc '%u' "$ALI_ENV")" != "$(id -u)" || "$(stat -Lc '%a' "$ALI_ENV")" != "600" ]]; then
  echo "AliNavigator Gateway資格情報: unsafe permissions"
  failed=1
else
  echo "AliNavigator Gateway資格情報: permissions OK"
fi

if [[ -x "$HOME/.local/bin/alinavigator-mcp-probe" ]] && "$HOME/.local/bin/alinavigator-mcp-probe" >/dev/null 2>&1; then
  echo "AliNavigator MCP stdio/tools: OK"
else
  echo "AliNavigator MCP stdio/tools: NG"
  failed=1
fi

if [[ -f "$PROFILE_DIR/alinavigator-mcp.yaml" ]] && command -v tunnel-client >/dev/null 2>&1; then
  if tunnel-client doctor --profile-dir "$PROFILE_DIR" --profile alinavigator-mcp >/dev/null 2>&1; then
    echo "AliNavigator MCP Tunnel profile: OK"
  else
    echo "AliNavigator MCP Tunnel profile: NG"
    failed=1
  fi
else
  echo "AliNavigator MCP Tunnel profile: missing"
  failed=1
fi

if systemctl_user is-active --quiet local-mcp-alinavigator-tunnel.service 2>/dev/null; then
  echo "AliNavigator MCP Tunnel service: active"
else
  echo "AliNavigator MCP Tunnel service: inactive"
  failed=1
fi

if [[ -s "$ADMIN_KEY" ]]; then
  if [[ "$(stat -Lc '%u' "$ADMIN_KEY")" != "$(id -u)" || "$(stat -Lc '%a' "$ADMIN_KEY")" != "600" ]]; then
    echo "Local MCP Admin key: unsafe permissions"
    failed=1
  elif [[ -s "$RUNTIME_KEY" ]] && command -v jq >/dev/null 2>&1 && [[ -f "$CODEXIFY_CONFIG" ]]; then
    hub_tunnel_id="$(jq -r '.openaiTunnel.tunnelId // .openaiTunnels[0].tunnelId // empty' "$CODEXIFY_CONFIG" 2>/dev/null)"
    if [[ "$hub_tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]] && \
       workspace_id="$(tunnel-client admin tunnels get "$hub_tunnel_id" --admin-key "file:$RUNTIME_KEY" --json 2>/dev/null | jq -r '.workspace_ids[0] // empty')" && \
       [[ -n "$workspace_id" ]] && \
       tunnel-client admin tunnels list --admin-key "file:$ADMIN_KEY" --workspace-id "$workspace_id" --json >/dev/null 2>&1; then
      echo "Local MCP Admin key: tunnel management OK"
    else
      echo "Local MCP Admin key: tunnel management NG"
      failed=1
    fi
  fi
fi

exit "$failed"

