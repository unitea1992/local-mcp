# Secure MCP Tunnel profileは専用Connectorだけ持つ

開発用TunnelはCodexify自身が管理するため、local-mcpのprofileにはしません。
XServerもCodexifyのMCP catalogへ移したため、専用profileは不要です。

現在local-mcpが管理する実profileはAliNavigator用の
`~/.config/local-mcp/tunnel-profiles/alinavigator-mcp.yaml` だけです。

Runtime API keyはprofileへ直書きせず、`~/.config/local-mcp/runtime-api-key` を `file:` 参照します。

~~~bash
tunnel-client profiles samples list
tunnel-client help quickstart
~~~

AliNavigatorの日常常駐管理は `local-mcp-alinavigator-tunnel.service` が担当します。
