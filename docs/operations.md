# 日常運用

開発・worktree・agent実行はT3 Codeが担当します。このリポジトリではAliNavigator Secure MCP Tunnelを管理します。

## 状態確認

~~~bash
./scripts/status.sh
./scripts/doctor.sh
./scripts/check.sh
~~~

Tunnelが応答しない場合はunitとprofileを確認します。

~~~bash
systemctl --user status local-mcp-alinavigator-tunnel.service
journalctl --user -u local-mcp-alinavigator-tunnel.service -n 100 --no-pager
tunnel-client doctor --profile-dir "$HOME/.config/local-mcp/tunnel-profiles" --profile alinavigator-mcp
~~~

Gateway Access資格情報は `~/.config/local-mcp/alinavigator.env`、runtime/admin keyはそれぞれのファイルに
mode 600で保存します。MCP launcherとprobeはalinavigator-api側が管理します。

## Tunnelの再設定・追加

既存Tunnelをprofileに設定するには次を使います。

~~~bash
./scripts/configure-alinavigator-tunnel.sh tunnel_...
~~~

新しいTunnelはOrganization IDとWorkspace IDを明示するか、scopeに使う既存Tunnel IDを指定します。

~~~bash
./scripts/create-secure-mcp-tunnel.sh "<name>" "<description>" "<organization-id>" "<workspace-id>"
# または
./scripts/create-secure-mcp-tunnel.sh "<name>" "<description>" "tunnel_<existing-id>"
~~~

作成されたIDを `configure-alinavigator-tunnel.sh` に渡してprofileとserviceを設定します。
どちらの経路もCodexify設定には依存しません。

## tunnel-clientを更新する

`config/tunnel-client.version` と `config/tunnel-client.sha256` を公式releaseと照合して更新し、次を実行します。

~~~bash
./scripts/install-tunnel-client.sh
./scripts/check.sh
systemctl --user restart local-mcp-alinavigator-tunnel.service
~~~
