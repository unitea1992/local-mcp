#!/usr/bin/env bash
set -u

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
  orca-ide repo list --json >/dev/null 2>&1 && echo "Orca CLI: OK" || {
    echo "Orca CLI: NG"
    failed=1
  }
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
  elif ! profiles_json="$(tunnel-client profiles list --json 2>/dev/null)"; then
    echo "Secure MCP Tunnel: profile一覧を取得できません"
    failed=1
  elif [[ "$(printf "%s" "$profiles_json" | jq 'length')" -eq 0 ]]; then
    echo "Secure MCP Tunnel: 未設定（まだ移行前なので正常です）"
  else
    count="$(printf "%s" "$profiles_json" | jq 'length')"
    echo "Secure MCP Tunnel: $count profile configured"
    echo "詳細診断は対象profileを指定して tunnel-client doctor --profile <name> --explain を実行します。"
  fi
else
  echo "tunnel-client: not installed (migration not started)"
  failed=1
fi

exit "$failed"

