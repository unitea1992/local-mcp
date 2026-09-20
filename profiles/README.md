# Secure MCP Tunnelの実profileはOrca用だけ持つ

実際に使うprofileは `~/.config/local-mcp/tunnel-profiles/orca-mcp.yaml` です。
リポジトリの外なのでGit管理されません。

Runtime API keyはprofileへ直書きせず、
`~/.config/local-mcp/runtime-api-key` を `file:` 参照します。

profileは現在インストールされている `tunnel-client` から生成します。

~~~bash
tunnel-client profiles samples list
tunnel-client help quickstart
~~~

表示名は `Orca MCP`、profile名は `orca-mcp` に揃えます。
日常の常駐管理は `local-mcp-orca-tunnel.service` が担当します。

DevSpaceはSecure MCP Tunnelを使わないため、`devspace-mcp` profileは持ちません。
