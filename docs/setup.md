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

tunnel-client runtimes connect \
  --alias orca-mcp \
  --profile orca-mcp \
  --profile-dir "$LOCAL_MCP_PROFILE_DIR" \
  --tunnel-id "$ORCA_TUNNEL_ID" \
  --runtime-api-key "file:$HOME/.config/local-mcp/runtime-api-key" \
  --mcp-command "node $LOCAL_MCP_ROOT/apps/orca-mcp/dist/index.js" \
  --json
~~~

ここではprofile生成と初回疎通を行います。
接続できたら、次のsystemd化で `runtimes connect` のtmux runtimeから切り替えます。

## Orca Tunnelをsystemdで常駐化する

~~~bash
./scripts/install-orca-tunnel-service.sh
~~~

このスクリプトは旧tmux runtimeを停止し、
`~/.config/systemd/user/local-mcp-orca-tunnel.service` をインストールして有効化します。

確認は次で行います。

~~~bash
systemctl --user status local-mcp-orca-tunnel.service
./scripts/status.sh
./scripts/doctor.sh
~~~

ChatGPT側では `Orca MCP` Connectorからworktree一覧を取得できれば完了です。

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

最終更新: 2026-09-20
