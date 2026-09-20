# Secure MCP Tunnelの実プロファイルはローカルだけに置く

profiles/local/ はGit管理外です。
Tunnel IDやAPI keyを含む可能性がある実ファイルはここに置き、コミットしません。

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
