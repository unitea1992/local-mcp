# Secure MCP Tunnelの実プロファイルはホーム配下だけに置く

実際に使うprofileは `~/.config/local-mcp/tunnel-profiles/` に置きます。
リポジトリの外なのでGit管理されません。
API keyはprofileへ直書きせず、`~/.config/local-mcp/runtime-api-key` を
`file:` 参照します。

プロファイルは現在インストールされている tunnel-client から生成します。
設定形式をこのリポジトリで独自に複製しないことで、公式クライアントの更新へ追従しやすくします。

~~~bash
tunnel-client profiles samples list
tunnel-client help quickstart
~~~

DevSpaceとOrcaには別々のTunnel IDを割り当てる方針です。
表示名は `DevSpace MCP` / `Orca MCP`、runtime aliasとprofileは
`devspace-mcp` / `orca-mcp` に揃えます。
stdio MCPは同じTunnel IDで複数の tunnel-client を同時起動しません。

DevSpaceのOAuth構成は [DevSpaceの認証設計](../docs/devspace-auth.md) を正本にします。
