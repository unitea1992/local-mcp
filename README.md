# local-mcp

ChatGPTからローカル開発環境へ接続する経路と、独立して残すSecure MCP Tunnelの運用を管理するリポジトリです。
個人利用を第一に、独自runtimeを増やさず既存実装を組み合わせます。

開発・worktree・エージェント実行はT3 Codeへ移行済みです。このリポジトリはAliNavigator向けなど独立したSecure MCP Tunnelのprofile、systemd、診断を管理します。Orca CLI／Codexify経由の開発Hubは現行経路に含みません。

開発の変更はT3 Codeの対象プロジェクトで行い、T3 Codeのworktree・thread・scheduled task機能を使います。

詳細は [設計](docs/architecture.md)、再構築は [セットアップ](docs/setup.md)、異常時は
[運用ガイド](docs/operations.md) を参照します。

## 日常運用

~~~bash
./scripts/status.sh
./scripts/doctor.sh
./scripts/check.sh
~~~

## AliNavigator Tunnel

AliNavigator MCP本体はalinavigator-api側で管理します。Tunnel作成時のOrganization / Workspace scopeは
CodexifyのTunnelから継承します。

## 秘密情報はGitに入れない

Runtime API keyは `~/.config/local-mcp/runtime-api-key` に置き、Gitへ保存しません。
CodexifyとAliNavigator Tunnelは同じRestricted keyを参照でき、TunnelsのRead + Useだけを持たせます。

AliNavigatorのGateway Access資格情報は `~/.config/local-mcp/alinavigator.env` に分離し、Gitへ保存しません。
Runtime / Admin API keyは現在のユーザー所有・mode 600で管理します。

`tunnel-client` は `config/tunnel-client.version` でバージョンを固定し、
`config/tunnel-client.sha256` に保存した検証済みSHA256と一致する公式release assetだけを導入します。

Tunnel管理用のAdmin API keyは `~/.config/local-mcp/admin-api-key` に置き、
Runtime API keyと同様に現在のユーザー所有・mode 600で管理します。
Admin keyは常駐serviceへ渡さず、Tunnel CRUD時だけ使用します。

## License

[MIT](LICENSE)

最終更新: 2026-09-27
