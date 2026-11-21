# local-mcpをセットアップする

このリポジトリはAliNavigator Secure MCP Tunnelのローカルprofile、systemd service、診断を管理します。
開発・worktree・agent実行の設定は行いません。開発運用はT3 Codeを使います。

## 前提

- `tunnel-client` は `./scripts/install-tunnel-client.sh` で導入する
- Tunnel runtime keyとadmin keyを `~/.config/local-mcp/runtime-api-key`、`~/.config/local-mcp/admin-api-key` に置き、所有者を現在のユーザー、modeを600にする
- AliNavigator API側でlauncherとprobeを用意する（`./mcp/scripts/install-local.sh`）
- Gateway Access資格情報を `~/.config/local-mcp/alinavigator.env` にmode 600で保存する

~~~text
ALINAVIGATOR_ACCESS_CLIENT_ID=...
ALINAVIGATOR_ACCESS_CLIENT_SECRET=...
~~~

## Tunnelを作成して設定する

Organization / Workspace IDを指定してTunnelを作成します。

~~~bash
./scripts/create-secure-mcp-tunnel.sh \
  "AliNavigator MCP" \
  "ChatGPTからAliNavigator APIを利用するローカルMCP" \
  "<organization-id>" \
  "<workspace-id>"
~~~

既存Tunnelからscopeを継承する場合は第3引数にそのTunnel IDを渡します。
出力された新しいTunnel IDでprofileとserviceを構成します。

~~~bash
./scripts/configure-alinavigator-tunnel.sh tunnel_...
~~~

この手順はCodexify設定を必要としません。終わったら状態と診断を確認します。

~~~bash
./scripts/status.sh
./scripts/doctor.sh
./scripts/check.sh
~~~

## 秘密情報

Runtime key、Admin key、Gateway Access資格情報はGitに入れず、現在のユーザー所有・mode 600で管理します。
Admin keyはTunnel CRUD時だけ使用し、常駐serviceには渡しません。
