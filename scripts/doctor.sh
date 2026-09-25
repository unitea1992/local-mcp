#!/usr/bin/env bash
set -u

PROFILE_DIR="${LOCAL_MCP_PROFILE_DIR:-$HOME/.config/local-mcp/tunnel-profiles}"
RUNTIME_ENV="$HOME/.config/local-mcp/tunnel.env"
ADMIN_KEY="$HOME/.config/local-mcp/admin-api-key"
RUNTIME_KEY="$HOME/.config/local-mcp/runtime-api-key"

if [[ -f "$RUNTIME_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$RUNTIME_ENV"
  set +a
fi

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

echo "== local-mcp doctor =="
echo

failed=0

if command -v devspace >/dev/null 2>&1; then
  echo "-- DevSpace --"
  tmp_devspace="$(mktemp)"
  if devspace doctor >"$tmp_devspace" 2>&1; then
    grep -E \
      '^(Node:|Platform:|Git:|SQLite native dependency:|Local MCP URL:|Public MCP URL:|Subagents:)' \
      "$tmp_devspace" || true
  else
    echo "DevSpace doctor: NG"
    failed=1
  fi
  rm -f "$tmp_devspace"
else
  echo "DevSpace: not installed"
  failed=1
fi

echo
echo "-- Orca --"
if command -v orca-ide >/dev/null 2>&1; then
  if orca-ide repo list --json >/dev/null 2>&1; then
    echo "Orca CLI: OK"
  else
    echo "Orca CLI: NG"
    failed=1
  fi
else
  echo "Orca CLI: not installed"
  failed=1
fi

echo
echo "-- Secure MCP Tunnel --"
if command -v tunnel-client >/dev/null 2>&1; then
  tunnel-client --version
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq: not installed"
    failed=1
  elif ! profiles_json="$(tunnel-client profiles list --profile-dir "$PROFILE_DIR" --json 2>/dev/null)"; then
    echo "Secure MCP Tunnel: profile一覧を取得できません"
    failed=1
  elif [[ "$(printf "%s" "$profiles_json" | jq 'length')" -eq 0 ]]; then
    echo "Secure MCP Tunnel: Orca profileがありません"
    failed=1
  else
    count="$(printf "%s" "$profiles_json" | jq 'length')"
    echo "Secure MCP Tunnel: $count profile configured"
    if [[ -n "${CONTROL_PLANE_ORGANIZATION_ID:-}" ]]; then
      echo "Orca MCP organization context: configured"
    else
      echo "Orca MCP organization context: missing"
      failed=1
    fi
    if tunnel-client doctor --profile-dir "$PROFILE_DIR" --profile orca-mcp >/dev/null 2>&1; then
      echo "Orca MCP Tunnel profile: OK"
    else
      echo "Orca MCP Tunnel profile: NG"
      failed=1
    fi
    if [[ -f "$PROFILE_DIR/xserver-mcp.yaml" ]]; then
      if tunnel-client doctor --profile-dir "$PROFILE_DIR" --profile xserver-mcp >/dev/null 2>&1; then
        echo "XServer MCP Tunnel profile: OK"
      else
        echo "XServer MCP Tunnel profile: NG"
        failed=1
      fi
    fi
    if [[ -f "$PROFILE_DIR/alinavigator-mcp.yaml" ]]; then
      if tunnel-client doctor --profile-dir "$PROFILE_DIR" --profile alinavigator-mcp >/dev/null 2>&1; then
        echo "AliNavigator MCP Tunnel profile: OK"
      else
        echo "AliNavigator MCP Tunnel profile: NG"
        failed=1
      fi
    fi
  fi
else
  echo "tunnel-client: not installed"
  failed=1
fi

if systemctl_user is-active --quiet local-mcp-orca-tunnel.service 2>/dev/null; then
  echo "Orca MCP Tunnel service: active"
else
  echo "Orca MCP Tunnel service: inactive"
  failed=1
fi

if [[ -s "$ADMIN_KEY" ]]; then
  if [[ "$(stat -Lc '%u' "$ADMIN_KEY")" != "$(id -u)" || "$(stat -Lc '%a' "$ADMIN_KEY")" != "600" ]]; then
    echo "Local MCP Admin key: unsafe permissions"
    failed=1
  elif [[ -f "$PROFILE_DIR/orca-mcp.yaml" && -s "$RUNTIME_KEY" ]]; then
    orca_tunnel_id="$(
      awk '
        $1 == "tunnel_id:" {
          gsub(/"/, "", $2)
          print $2
          exit
        }
      ' "$PROFILE_DIR/orca-mcp.yaml"
    )"
    if workspace_id="$(
      tunnel-client admin tunnels get "$orca_tunnel_id" \
        --admin-key "file:$RUNTIME_KEY" \
        --json 2>/dev/null | jq -r '.workspace_ids[0] // empty'
    )" && [[ -n "$workspace_id" ]] && \
       tunnel-client admin tunnels list \
         --admin-key "file:$ADMIN_KEY" \
         --workspace-id "$workspace_id" \
         --json >/dev/null 2>&1; then
      echo "Local MCP Admin key: tunnel management OK"
    else
      echo "Local MCP Admin key: tunnel management NG"
      failed=1
    fi
  fi
fi

if [[ -f "$PROFILE_DIR/xserver-mcp.yaml" ]]; then
  if systemctl_user is-active --quiet local-mcp-xserver-tunnel.service 2>/dev/null; then
    echo "XServer MCP Tunnel service: active"
  else
    echo "XServer MCP Tunnel service: inactive"
    failed=1
  fi
fi

if [[ -f "$PROFILE_DIR/alinavigator-mcp.yaml" ]]; then
  credentials_env="$HOME/.config/local-mcp/alinavigator.env"
  if [[ ! -s "$credentials_env" ]]; then
    echo "AliNavigator Gateway資格情報: missing"
    failed=1
  elif [[ "$(stat -Lc '%u' "$credentials_env")" != "$(id -u)" || "$(stat -Lc '%a' "$credentials_env")" != "600" ]]; then
    echo "AliNavigator Gateway資格情報: unsafe permissions"
    failed=1
  else
    echo "AliNavigator Gateway資格情報: permissions OK"
  fi
  if [[ ! -x "$HOME/.local/bin/alinavigator-mcp" ]]; then
    echo "AliNavigator MCP launcher: missing"
    failed=1
  fi
  if [[ ! -x "$HOME/.local/bin/alinavigator-mcp-probe" ]]; then
    echo "AliNavigator MCP probe: missing"
    failed=1
  elif "$HOME/.local/bin/alinavigator-mcp-probe" >/dev/null 2>&1; then
    echo "AliNavigator MCP stdio/tools: OK"
  else
    echo "AliNavigator MCP stdio/tools: NG"
    failed=1
  fi
  if [[ -s "$credentials_env" ]] && \
     [[ "$(stat -Lc '%u' "$credentials_env")" == "$(id -u)" ]] && \
     [[ "$(stat -Lc '%a' "$credentials_env")" == "600" ]] && \
     [[ -x "$HOME/.local/bin/alinavigator-mcp-probe" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$credentials_env"
    set +a
    if "$HOME/.local/bin/alinavigator-mcp-probe" --gateway >/dev/null 2>&1; then
      echo "AliNavigator Gateway MCP probe: OK"
    else
      echo "AliNavigator Gateway MCP probe: NG"
      failed=1
    fi
    unset ALINAVIGATOR_ACCESS_CLIENT_ID ALINAVIGATOR_ACCESS_CLIENT_SECRET
  fi
  if systemctl_user is-active --quiet local-mcp-alinavigator-tunnel.service 2>/dev/null; then
    echo "AliNavigator MCP Tunnel service: active"
  else
    echo "AliNavigator MCP Tunnel service: inactive"
    failed=1
  fi
fi

exit "$failed"

