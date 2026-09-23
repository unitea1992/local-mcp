#!/usr/bin/env bash
set -u

PROFILE_DIR="${LOCAL_MCP_PROFILE_DIR:-$HOME/.config/local-mcp/tunnel-profiles}"

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

echo "== local-mcp status =="
echo

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf "%-16s OK  %s\n" "$name" "$(command -v "$name")"
  else
    printf "%-16s --  not installed\n" "$name"
  fi
}

check_command node
check_command pnpm
check_command rumdl
check_command jq
check_command orca-ide
check_command devspace
check_command tunnel-client

echo
if command -v devspace >/dev/null 2>&1; then
  printf "DevSpace:       "
  devspace --version 2>/dev/null || echo "version unavailable"
fi

if command -v orca-ide >/dev/null 2>&1; then
  printf "Orca:           "
  orca-ide --version 2>/dev/null || echo "version unavailable"
fi

if command -v tunnel-client >/dev/null 2>&1; then
  printf "tunnel-client:  "
  tunnel-client --version 2>/dev/null || echo "version unavailable"
  echo
  printf "Secure MCP Tunnel profiles: "
  if profiles_json="$(tunnel-client profiles list --profile-dir "$PROFILE_DIR" --json 2>/dev/null)"; then
    printf "%s configured\n" "$(printf "%s" "$profiles_json" | jq 'length')"
  else
    echo "status unavailable"
  fi
  echo
  printf "Orca Tunnel service: "
  if systemctl_user is-active --quiet local-mcp-orca-tunnel.service 2>/dev/null; then
    echo "active"
  else
    echo "inactive"
  fi
  if [[ -f "$PROFILE_DIR/xserver-mcp.yaml" || -f "$HOME/.config/systemd/user/local-mcp-xserver-tunnel.service" ]]; then
    printf "XServer Tunnel service: "
    if systemctl_user is-active --quiet local-mcp-xserver-tunnel.service 2>/dev/null; then
      echo "active"
    else
      echo "inactive"
    fi
  fi
fi

echo
if command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale Funnel:"
  tailscale funnel status 2>/dev/null || echo "  status unavailable"
fi

