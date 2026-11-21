#!/usr/bin/env bash
set -u

PROFILE_DIR="${LOCAL_MCP_PROFILE_DIR:-$HOME/.config/local-mcp/tunnel-profiles}"
ADMIN_KEY="$HOME/.config/local-mcp/admin-api-key"
RUNTIME_KEY="$HOME/.config/local-mcp/runtime-api-key"
ALI_ENV="$HOME/.config/local-mcp/alinavigator.env"
failed=0

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
  elif command -v jq >/dev/null 2>&1 && [[ -s "$PROFILE_DIR/alinavigator-mcp.yaml" ]]; then
    tunnel_id="$(awk '$1 == "tunnel_id:" {gsub(/"/, "", $2); print $2; exit}' "$PROFILE_DIR/alinavigator-mcp.yaml")"
    if [[ "$tunnel_id" =~ ^tunnel_[0-9a-f]{32}$ ]] && \
       tunnel-client admin tunnels get "$tunnel_id" --admin-key "file:$ADMIN_KEY" --json >/dev/null 2>&1; then
      echo "Local MCP Admin key: tunnel management OK"
    else
      echo "Local MCP Admin key: tunnel management NG"
      failed=1
    fi
  fi
fi

exit "$failed"

