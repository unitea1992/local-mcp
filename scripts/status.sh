#!/usr/bin/env bash
set -u

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
  if profiles_json="$(tunnel-client profiles list --json 2>/dev/null)"; then
    printf "%s configured\n" "$(printf "%s" "$profiles_json" | jq 'length')"
  else
    echo "status unavailable"
  fi
  echo
  echo "Managed runtimes:"
  tunnel-client runtimes list --json 2>/dev/null \
    | jq -r 'if (.aliases | length) == 0 then "  none" else .aliases[] | "  \(.alias // .name // .tunnel_id // "unknown")" end' \
    2>/dev/null || echo "  status unavailable"
fi

echo
if command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale Funnel:"
  tailscale funnel status 2>/dev/null || echo "  status unavailable"
fi

