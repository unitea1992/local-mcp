#!/usr/bin/env bash
set -u

PROFILE_DIR="${LOCAL_MCP_PROFILE_DIR:-$HOME/.config/local-mcp/tunnel-profiles}"
RUNTIME_ENV="$HOME/.config/local-mcp/tunnel.env"

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

exit "$failed"

