# 初回セットアップはDevSpaceとOrcaを別々に考える

この章は初回セットアップや再構築時に使います。
普段の確認は [運用ガイド](operations.md) を参照してください。

2026-09-20時点の確認済み構成は、DevSpace 1.1.0-beta.4、Orca 1.4.205、
tunnel-client 0.0.14、Node.js 24.20.0、pnpm 11.25.0です。

## DevSpaceは既存のFunnel + OAuthを使う

DevSpaceは `127.0.0.1:7676` で起動し、`server.publicBaseUrl` にTailscale FunnelのHTTPS originを設定します。
ChatGPT側では `DevSpace Local` として接続し、DevSpaceのOAuth認可を完了します。

DevSpace用のSecure MCP Tunnel profileやTunnel IDは作りません。
過去に作成したDevSpace用Tunnelは [DevSpaceの接続方式](devspace-auth.md) の検証履歴として扱い、運用には使いません。

## Orca用TunnelをOpenAI Platformで作る

表示名は `Orca MCP`、ローカルのprofile名は `orca-mcp` にします。
個人で使うChatGPT Workspaceへ関連付けます。

常駐runtime用のAPI keyはTunnelsのRead + Useだけを許可したRestricted keyにします。
Manage権限は付けません。

Tunnel管理用には `Local MCP Admin` というAdmin API keyを別途用意し、
`~/.config/local-mcp/admin-api-key` に通常ファイル・mode 600で保存します。
Runtime keyとAdmin keyは `local-mcp` 自身が所有するため、同じ `~/.config/local-mcp/` に揃えます。
サービス固有secretは `~/projects/.secrets/<repo>/` を正本とし、local-mcp側へ必要な場合だけ参照を作ります。

新しいTunnelは既存Orca TunnelのOrganization / Workspace scopeを継承して作成できます。

~~~bash
./scripts/create-secure-mcp-tunnel.sh \
  "AliNavigator MCP" \
  "ChatGPTからAliNavigator APIを利用し、AliExpressとAmazon.co.jpの商品情報を取得するためのローカルMCP"
~~~

Tunnel管理を自動化する場合は、Platformで `Local MCP Admin` というAdmin API keyを別途作成し、
`~/.config/local-mcp/admin-api-key` に直接保存します。
Runtime keyと同様、symlinkではなく通常ファイルとしてmode 600で管理します。
このAdmin keyはsystemdや長寿命runtimeへ渡さず、Tunnel CRUD時だけ利用します。

~~~bash
read -rsp "Local MCP Admin API key: " LOCAL_MCP_ADMIN_KEY
printf '\n'
printf '%s' "$LOCAL_MCP_ADMIN_KEY" > "$HOME/.config/local-mcp/admin-api-key"
chmod 600 "$HOME/.config/local-mcp/admin-api-key"
unset LOCAL_MCP_ADMIN_KEY
~~~

~~~bash
install -d -m 700 "$HOME/.config/local-mcp"

read -rsp "Runtime API key: " LOCAL_MCP_RUNTIME_KEY
printf '\n'
printf '%s' "$LOCAL_MCP_RUNTIME_KEY" > "$HOME/.config/local-mcp/runtime-api-key"
chmod 600 "$HOME/.config/local-mcp/runtime-api-key"
unset LOCAL_MCP_RUNTIME_KEY
~~~

## Orca MCP profileを作る

~~~bash
pnpm install
pnpm build

export ORCA_TUNNEL_ID='tunnel_...'
export LOCAL_MCP_PROFILE_DIR="$HOME/.config/local-mcp/tunnel-profiles"
LOCAL_MCP_ROOT="$(git rev-parse --show-toplevel)"

tunnel-client init \
  --profile orca-mcp \
  --profile-dir "$LOCAL_MCP_PROFILE_DIR" \
  --tunnel-id "$ORCA_TUNNEL_ID" \
  --control-plane-api-key-ref "file:$HOME/.config/local-mcp/runtime-api-key" \
  --mcp-command "node $LOCAL_MCP_ROOT/apps/orca-mcp/dist/index.js" \
  --health-listen-addr 127.0.0.1:0
~~~

ここではprofileだけを生成します。
常駐起動は次のsystemd serviceに任せるため、`runtimes connect` は使いません。

## Orca Tunnelをsystemdで常駐化する

~~~bash
./scripts/install-orca-tunnel-service.sh
~~~

このスクリプトは旧tmux runtimeを停止し、
`~/.config/systemd/user/local-mcp-orca-tunnel.service` をインストールして有効化します。
同時にTunnel metadataからorganization IDを取得し、
`~/.config/local-mcp/tunnel.env` へ `CONTROL_PLANE_ORGANIZATION_ID` として保存します。
この値はGitへ入れず、systemd serviceだけが読み込みます。

`tunnel-client 0.0.14` では、organizationへ関連付けたTunnelを長寿命runtimeから使う場合、
organization contextを明示しておくと認可エラーを切り分けやすくなります。
既知のTunnel IDに対するmetadata取得には、同じRestricted runtime keyを使います。

確認は次で行います。

~~~bash
systemctl --user status local-mcp-orca-tunnel.service
./scripts/status.sh
./scripts/doctor.sh
~~~

ChatGPT側では `Orca MCP` Connectorからworktree一覧を取得できれば完了です。

## XServer MCPをChatGPTへ接続する

OpenAI Platformで `XServer MCP` という別Tunnelを作り、Orca MCPと同じOrganization / ChatGPT Workspaceへ関連付けます。
常駐runtime用API keyは新規発行せず、既存の `~/.config/local-mcp/runtime-api-key` を共有します。
XServer側の認証は `~/.local/bin/xserver-mcp-official` が既存の暗号化credentialから読み込みます。

Tunnel IDを取得したら次を実行します。

~~~bash
./scripts/configure-xserver-tunnel.sh tunnel_...
~~~

このスクリプトは次をまとめて行います。

1. Tunnelが既存Orca Tunnelと同じOrganization / Workspaceに属することを確認する
2. `xserver-mcp` profileを生成する
3. `local-mcp-xserver-tunnel.service` を有効化して起動する

serviceは `Restart=always` で、user lingerが有効な環境ではOS再起動後も自動復帰します。

ChatGPT側では新規プラグインの接続方式を「トンネル」にし、作成した `XServer MCP` Tunnelを選択します。
XServer API keyはread-onlyのまま使います。

## AliNavigator MCPをChatGPTへ接続する

MCP本体は alinavigator-api リポジトリで管理します。先に同リポジトリで次を実行し、launcherを作ります。

~~~bash
./mcp/scripts/install-local.sh
~~~

Gateway AccessのService Tokenは次の2変数として ~/.config/local-mcp/alinavigator.env に保存し、mode 600にします。実値はこのリポジトリへ保存しません。
configure / install / doctorでも所有者とmode 600を検査します。

~~~text
ALINAVIGATOR_ACCESS_CLIENT_ID=...
ALINAVIGATOR_ACCESS_CLIENT_SECRET=...
~~~

OpenAI Platformで AliNavigator MCP 用Tunnelを作り、
Orca MCPと同じOrganization / ChatGPT Workspaceへ関連付けます。
Tunnel IDを取得したら次を実行します。

~~~bash
./scripts/configure-alinavigator-tunnel.sh tunnel_...
~~~

このスクリプトはprofileを alinavigator-mcp として生成し、
local-mcp-alinavigator-tunnel.service を有効化します。
MCP commandには ~/.local/bin/alinavigator-mcp を使うため、
local-mcp側は alinavigator-api のcheckoutパスを保持しません。
設定前に ~/.local/bin/alinavigator-mcp-probe でstdio接続とtools/listも確認します。

## 秘密値を出さずに診断する

~~~bash
./scripts/status.sh
./scripts/doctor.sh
journalctl --user -u local-mcp-orca-tunnel.service -n 100 --no-pager
~~~

API key、OAuth token、Owner passwordはChatGPTへ貼り付けません。
設定確認が必要な場合も秘密値そのものではなく、権限・パス・HTTP statusを確認します。

## 参考にする正本

- OpenAI Secure MCP Tunnel: <https://developers.openai.com/api/docs/guides/secure-mcp-tunnels>
- OpenAI tunnel-client: <https://github.com/openai/tunnel-client>
- DevSpace configuration: <https://github.com/Waishnav/devspace/blob/main/docs/configuration.md>

最終更新: 2026-09-25
