# local-mcp

ChatGPTからローカル開発環境へ接続する経路と、Orca向けMCPを管理するリポジトリです。

現在は役割ごとに接続方式を分けています。

~~~text
ChatGPT
  │
  ├─ DevSpace Local ─ Tailscale Funnel ─ DevSpace + OAuth
  │
  └─ Orca MCP ─ Secure MCP Tunnel ─ orca-mcp ─ Orca ─ OMP / OpenCode / Codex
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
常駐Orca TunnelにはTunnelsのRead + Useだけを持つRestricted keyを使います。

実際のTunnel profileは `~/.config/local-mcp/tunnel-profiles/` に置きます。
リポジトリには生成手順と運用方針だけを残します。

最終更新: 2026-09-20
