# 初回セットアップはOrcaから始め、DevSpaceはOAuth確認後に切り替える

この章は初回だけ上から順に進めます。
普段の確認は [運用ガイド](operations.md) を使います。

現時点でローカル側のOrca MCPと tunnel-client の準備までは完了しています。
OpenAI Platform側でTunnelとRestricted API keyを作る操作だけは、ユーザーのアカウントで行う必要があります。

## ローカル環境が正常か確認する

~~~bash
./scripts/status.sh
./scripts/check.sh
~~~

2026-09-20時点では、次の構成でローカルPoCを確認しています。

| 項目 | 確認済みバージョン |
| --- | --- |
| tunnel-client | 0.0.14 |
| Orca | 1.4.205 |
| DevSpace | 1.1.0-beta.4 |
| Node.js | 24.20.0 |
| pnpm | 11.25.0 |
| rumdl | 0.2.74 |

tunnel-client は、このリポジトリで動作確認したバージョンを固定して使います。
新しいリリースへ更新するときは、OpenAI公式Docsとリリース内容を確認してから
`config/tunnel-client.version` を更新し、`./scripts/install-tunnel-client.sh` を実行します。

## OpenAI PlatformでTunnelを2本作る

Orca用とDevSpace用を分けます。
片方の設定に問題が起きても、もう片方を復旧経路として残せるためです。

表示名は `Orca MCP` と `DevSpace MCP` を推奨します。
ローカルで使うaliasとprofileは `orca-mcp` と `devspace-mcp` に揃えます。
それぞれ、利用するChatGPT WorkspaceまたはOrganizationへ関連付けます。
作成後に表示されるTunnel IDはGitへ保存しません。

## 常駐用のRestricted API keyを履歴に残さず保存する

tunnel-client の常駐runtimeには、TunnelsのRead + Useだけを許可したRestricted keyを使います。
Tunnelの作成・更新に必要なManage権限は付けません。

Runtime API keyはシェル履歴やリポジトリへ残さず、権限を絞ったローカルファイルへ保存します。

~~~bash
install -d -m 700 "$HOME/.config/local-mcp"
read -rsp "Runtime API key: " LOCAL_MCP_RUNTIME_KEY
printf '\n'
printf '%s' "$LOCAL_MCP_RUNTIME_KEY" > "$HOME/.config/local-mcp/runtime-api-key"
chmod 600 "$HOME/.config/local-mcp/runtime-api-key"
unset LOCAL_MCP_RUNTIME_KEY

export ORCA_TUNNEL_ID='tunnel_...'
export DEVSPACE_TUNNEL_ID='tunnel_...'
~~~

Tunnel IDは秘密情報ではありませんが、このリポジトリにはコミットしません。

## Orca MCPを先に接続する

Orca MCPはstdioなので、OAuthやHTTPサーバーの設定が不要です。
先にこちらでSecure MCP Tunnelそのものの疎通を確認します。

~~~bash
pnpm build
LOCAL_MCP_ROOT="$(git rev-parse --show-toplevel)"

tunnel-client runtimes connect \
  --alias orca-mcp \
  --profile orca-mcp \
  --tunnel-id "$ORCA_TUNNEL_ID" \
  --runtime-api-key "file:$HOME/.config/local-mcp/runtime-api-key" \
  --mcp-command "node $LOCAL_MCP_ROOT/apps/orca-mcp/dist/index.js" \
  --json

tunnel-client runtimes status orca-mcp --json
~~~

ChatGPT側ではSecure MCP Tunnelを使う接続先として、Orca用Tunnel IDを選びます。
接続後はworktree一覧とterminal一覧から確認します。

既存terminalの出力も読み取れます。
途中案件を引き継ぐ場合は、対象terminalを確認してから `orca_attach_terminal` を実行すると、
そのterminalへ追加指示を送れます。
attach対象はOrcaがOMP / OpenCode / Codexとして認識しているterminalに限ります。
既存terminalの終了だけはChatGPTから行いません。

## DevSpaceはOAuth込みで確認する

DevSpaceは `http://127.0.0.1:7676/mcp` で動作し、OAuthで保護されています。
tunnel-client が用意するDCR向けサンプルからプロファイルを生成します。

~~~bash
tunnel-client init \
  --sample sample_mcp_with_dcr \
  --profile devspace-mcp \
  --tunnel-id "$DEVSPACE_TUNNEL_ID" \
  --mcp-server-url http://127.0.0.1:7676/mcp \
  --control-plane-api-key-ref "file:$HOME/.config/local-mcp/runtime-api-key"

tunnel-client doctor --profile devspace-mcp --explain
~~~

loopback HTTPのOAuth discoveryで追加設定が必要な場合は、doctorの結果と、
現在インストールされている tunnel-client の設定リファレンスを正本にして調整します。
古い手順からフラグを推測して追加しません。

DevSpace側ではSecure Tunnelが使う正確なMCP Resource URLを `oauth.allowedResourceUrls` に追加する必要があります。
このURLはTunnel作成後の実値を確認して設定し、推測で組み立てません。

## DevSpaceのTailscale Funnelは最後に止める

現在のDevSpaceは、ブラウザで行うOAuth認可のために `publicBaseUrl` を使っています。
Secure MCP TunnelはMCP本体への経路を非公開にできますが、OAuthの認可画面まで自動的に非公開化するものではありません。

次の3点を確認するまでは既存Funnelを残します。

1. Secure MCP Tunnel経由でDevSpaceのtool discoveryが成功する。
2. ChatGPTからDevSpaceのOAuth認証を完了できる。
3. 読み取りと安全なテスト操作がSecure MCP Tunnel経由で成功する。

この確認後に、Funnelを完全停止できるか、OAuth認可用の最小公開面だけ残すかを判断します。

## 問題が起きたら秘密値を出さずに診断する

~~~bash
./scripts/status.sh
./scripts/doctor.sh
tunnel-client runtimes status orca-mcp --json
tunnel-client doctor --profile devspace-mcp --explain
~~~

API key、OAuth token、パスワードはChatGPTへ貼り付けません。
診断結果だけで判断できない場合は、秘密値を伏せた設定とログを確認します。

## 参考にする正本

- OpenAI Secure MCP Tunnel: <https://developers.openai.com/api/docs/guides/secure-mcp-tunnels>
- OpenAI tunnel-client: <https://github.com/openai/tunnel-client>
- DevSpace configuration: <https://github.com/Waishnav/devspace/blob/main/docs/configuration.md>

最終更新: 2026-09-20
