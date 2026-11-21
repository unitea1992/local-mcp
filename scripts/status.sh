#!/usr/bin/env bash
set -u

ADMIN_KEY="$HOME/.config/local-mcp/admin-api-key"

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

for name in tunnel-client jq; do
  if command -v "$name" >/dev/null 2>&1; then
    printf "%-16s OK  %s\n" "$name" "$(command -v "$name")"
  else
    printf "%-16s --  not installed\n" "$name"
  fi
done

echo
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

