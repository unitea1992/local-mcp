#!/usr/bin/env bash
set -u

ADMIN_KEY="$HOME/.config/local-mcp/admin-api-key"
CODEXIFY_CONFIG="${CODEXIFY_CONFIG:-$HOME/.codexify/codexify.config.json}"
CODEXIFY_BIN="${CODEXIFY_BIN:-}"

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

echo "== local-mcp status =="
echo

if [[ -x "$CODEXIFY_BIN" ]]; then
  printf "%-16s OK  %s\n" codexify "$CODEXIFY_BIN"
else
  printf "%-16s --  not installed\n" codexify
fi

for name in orca-ide tunnel-client jq rumdl; do
  if command -v "$name" >/dev/null 2>&1; then
    printf "%-16s OK  %s\n" "$name" "$(command -v "$name")"
  else
    printf "%-16s --  not installed\n" "$name"
  fi
done

echo
printf "Codexify service: "
if systemctl_user is-active --quiet codexify.service 2>/dev/null; then
  echo "active"
else
  echo "inactive"
fi

if [[ -x "$CODEXIFY_BIN" ]]; then
  "$CODEXIFY_BIN" --config "$CODEXIFY_CONFIG" service status 2>/dev/null | sed -n '1,8p' || true
fi

echo
if command -v orca-ide >/dev/null 2>&1; then
  printf "Orca:            "
  orca-ide --version 2>/dev/null || echo "version unavailable"
fi

printf "AliNavigator Tunnel: "
if systemctl_user is-active --quiet local-mcp-alinavigator-tunnel.service 2>/dev/null; then
  echo "active"
else
  echo "inactive"
fi

printf "Local MCP Admin key: "
if [[ ! -s "$ADMIN_KEY" ]]; then
  echo "not configured"
elif [[ "$(stat -Lc '%u' "$ADMIN_KEY")" == "$(id -u)" && "$(stat -Lc '%a' "$ADMIN_KEY")" == "600" ]]; then
  echo "configured (mode 600)"
else
  echo "configured (unsafe permissions)"
fi

