# local-mcpの責務

開発環境・worktree・agent orchestrationはT3 Codeが担当します。このリポジトリは開発Hubを提供せず、
独立して維持するSecure MCP Tunnelとローカルサービスの構成を管理します。

## AliNavigator Tunnel

- MCP本体とlauncherは `alinavigator-api` 側で管理します。
- このリポジトリはローカルTunnel profile、systemd unit、資格情報の配置・診断を管理します。
- Gateway Access資格情報とTunnel API keyはGitに含めず、ユーザー所有・mode 600で保存します。
- Tunnelの状態確認は `scripts/status.sh`、`scripts/doctor.sh`、`tunnel-client doctor` で行います。

## 開発作業

リポジトリの変更はT3 Codeで対象projectを選び、threadとworktreeを使って進めます。
定期実行はT3 Codeのscheduled taskに登録します。Orca CLI、Run/Task/Dispatch ID、
Orca Codexify Skillは現行構成の依存ではありません。

## 旧設計資料

`agent-compatibility.md` と `local-dev-hub-capabilities.md` はCodexify／Orca時代の調査記録です。現在のagent互換性や実行手順を示す資料としては参照しないでください。
