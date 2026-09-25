# local-mcp

ChatGPTから各MCPへ接続する経路と、Secure MCP Tunnelの運用を管理するリポジトリです。
MCP本体は、Orca MCPを除いて各サービス側のリポジトリで管理します。

現在は役割ごとに接続方式を分けています。

~~~text
ChatGPT
  │
  ├─ DevSpace Local ─ Tailscale Funnel ─ DevSpace + OAuth
  ├─ Orca MCP ─ Secure MCP Tunnel ─ orca-mcp ─ Orca ─ OMP / OpenCode / Codex
  ├─ XServer MCP ─ Secure MCP Tunnel ─ XServer公式MCP ─ XServer API
  └─ AliNavigator MCP ─ Secure MCP Tunnel ─ alinavigator-mcp ─ api.ali-navi.com
~~~

DevSpaceはもともとのHTTP + OAuth構成をそのまま使います。
Orca MCPは公開HTTPサーバーを持たず、OpenAI Secure MCP Tunnelからstdioで起動します。

## 最初はREADMEと設計だけ読めばよい

初回はこのREADMEと [設計](docs/architecture.md) まで読めば十分です。
セットアップをやり直すときは [セットアップ](docs/setup.md)、異常時は [運用ガイド](docs/operations.md) を参照します。

DevSpaceをSecure MCP Tunnelへ移す案も実機検証しましたが、OAuthのresource aliasやHarpoonを含む構成が増える割に、
個人利用では既存のDevSpace OAuthに対する利点が小さいため採用しませんでした。
判断経緯は [DevSpaceの接続方式](docs/devspace-auth.md) に残しています。

## 役割を分ける

| 経路 | 用途 | 認証・保護 |
| --- | --- | --- |
| DevSpace Local | ファイル、shell、Git、ローカルagent | DevSpace OAuth + Tailscale Funnel |
| Orca MCP | Orca terminalとOMP / OpenCode / Codexの操作 | Secure MCP Tunnel + ChatGPT Workspace |
| XServer MCP | XServerの設定・負荷・ログ・ドメイン情報の参照 | Secure MCP Tunnel + read-only XServer API key |
| AliNavigator MCP | AliExpress / Amazonの商品検索・比較用API | Secure MCP Tunnel + Gateway Access Service Token |

`DevSpace Local` も通信方式はMCPです。
名前の `Local` は「Secure MCP Tunnel版ではなく、既存のDevSpaceへ直接接続する経路」という識別用です。

## 日常運用はスクリプトへ寄せる

~~~bash
./scripts/status.sh
./scripts/doctor.sh
./scripts/check.sh
~~~

Orca Tunnelを初めて常駐化するときは次を使います。

~~~bash
./scripts/install-orca-tunnel-service.sh
~~~

XServer用TunnelをPlatformで作成した後は、Tunnel IDを指定してprofileと常駐serviceをまとめて設定します。

~~~bash
./scripts/configure-xserver-tunnel.sh tunnel_...
~~~

AliNavigator用Tunnelも同じ運用で、MCP本体は alinavigator-api 側に置きます。
先に alinavigator-api でlauncherを用意し、Gateway Access資格情報を
~/.config/local-mcp/alinavigator.env に保存してから設定します。

~~~bash
./scripts/configure-alinavigator-tunnel.sh tunnel_...
~~~

`tunnel-client` 自体の更新は `./scripts/install-tunnel-client.sh` で行います。
OpenAI公式リリースのSHA256を検証し、このリポジトリで確認済みのバージョンを導入します。

## Orca MCPは既存セッションをそのまま扱う

Orca MCPでは、既存terminalの一覧・状態・出力を読めます。
途中まで進めたOMP / OpenCode / Codexの作業をChatGPTから確認し、必要なterminalだけ引き継げます。

既存terminalへ入力するときは `orca_attach_terminal` を1回挟みます。
attachできるのはOrcaがagentとして認識しているterminalだけです。
既存terminalはChatGPTから閉じず、orca-mcp自身が起動したterminalだけ終了できます。

新しい作業は `orca_create_agent_worktree` でworktreeとagentをまとめて起動します。
Orcaに設定したagent commandや既定引数を迂回しません。

## 秘密情報はGitに入れない

Runtime API keyは `~/.config/local-mcp/runtime-api-key` に置き、Gitへ保存しません。
常駐Orca / XServer / AliNavigator Tunnelは同じRestricted keyを共有し、TunnelsのRead + Useだけを持たせます。
AliNavigatorのGateway Access資格情報は ~/.config/local-mcp/alinavigator.env に分離し、Gitへ保存しません。

Tunnel管理用のAdmin API keyは `~/.config/local-mcp/admin-api-key` に置き、
Runtime API keyと同様に現在のユーザー所有・mode 600で管理します。
Admin keyは常駐serviceへ渡さず、Tunnel CRUD時だけ使用します。

秘密情報の置き場所は「所有するリポジトリ」を基準にします。
`local-mcp` 自身のRuntime / Admin keyは `~/.config/local-mcp/`、
サービス固有の資格情報は `~/projects/.secrets/<repo>/` を正本にし、必要なら `~/.config/local-mcp/` から参照します。

Tunnel管理用のAdmin API keyは `~/.config/local-mcp/admin-api-key` に直接保存し、
Runtime API keyと同様に現在のユーザー所有・mode 600で管理します。
Admin keyは常駐serviceへ渡さず、Tunnelの作成・更新・削除を行う明示的な管理操作だけで使います。

実際のTunnel profileは `~/.config/local-mcp/tunnel-profiles/` に置きます。
リポジトリには生成手順と運用方針だけを残します。

最終更新: 2026-09-25
