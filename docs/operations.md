# 普段はstatus、異常時だけ個別経路を見る

このガイドは日常運用の逆引き用です。
構成全体を確認したい場合は [設計](architecture.md) を参照してください。

## 今の状態を確認したい → status.sh

~~~bash
./scripts/status.sh
~~~

DevSpace、Orca、tunnel-client、Orca Tunnel service、Tailscale Funnelの状態をまとめて確認します。
秘密情報の値は表示しません。

## 何か動かない → doctor.sh

~~~bash
./scripts/doctor.sh
~~~

DevSpaceの診断、Orca CLI、`orca-mcp` profile、Orca Tunnel serviceを確認します。

## Orca MCPだけ接続できない → systemdログを見る

~~~bash
systemctl --user status local-mcp-orca-tunnel.service
journalctl --user -u local-mcp-orca-tunnel.service -n 100 --no-pager
~~~

serviceを入れ直す場合は次を実行します。

~~~bash
./scripts/install-orca-tunnel-service.sh
~~~

profileは `~/.config/local-mcp/tunnel-profiles/orca-mcp.yaml`、
Runtime API keyは `~/.config/local-mcp/runtime-api-key` にあります。
organization contextは `~/.config/local-mcp/tunnel.env` にあります。

ChatGPT側で `tunnel_active_organization_required` が出る場合は、
まず `doctor.sh` でローカルruntimeのorganization contextが設定済みか確認します。
ローカル側が正常でもChatGPTから同じエラーになる事象は、
2026-09-20時点でopenai/tunnel-clientのIssue #61として報告されています。
この場合はローカル設定を増やして回避せず、Connector側の再接続またはupstream修正を確認します。

## DevSpace Localだけ接続できない → DevSpaceとFunnelを見る

~~~bash
systemctl --user status devspace.service
devspace doctor
tailscale funnel status
~~~

DevSpaceはSecure MCP Tunnelを使いません。
`server.publicBaseUrl`、DevSpace OAuth、Tailscale Funnelの3点を確認します。

過去の `devspace-mcp` Tunnel profileやresource aliasは現在の運用には不要です。
経緯は [DevSpaceの接続方式](devspace-auth.md) にあります。

## Orcaの途中作業を引き継ぐ

まずworktreeとterminalを確認し、必要なterminalの出力を読みます。
書き込みが必要な場合だけ `orca_attach_terminal` を実行し、その後 `orca_send_terminal` を使います。

Secure MCP Tunnelやorca-mcpが再起動してもOrcaのterminalは残ります。
再起動後は対象terminalを読み直し、必要なら再度attachします。

## 新しいOrca agentを起動する

`orca_create_agent_worktree` を使い、worktreeとOMP / OpenCode / Codexをまとめて作ります。
既存worktreeに新しいagentが必要な場合はOrca側から起動し、そのterminalをChatGPTからattachします。

## tunnel-clientを更新する

~~~bash
./scripts/install-tunnel-client.sh
./scripts/check.sh
systemctl --user restart local-mcp-orca-tunnel.service
~~~

更新後は `status.sh` と `doctor.sh` を実行します。
Tunnel Clientの設定形式はバージョン依存なので、更新時は公式Docsと `--help` を正本にします。

## 用語

| 用語 | このリポジトリでの意味 |
| --- | --- |
| DevSpace Local | Tailscale Funnel + DevSpace OAuthで直接接続するMCP |
| Orca MCP | Secure MCP Tunnel経由で使う自作stdio MCP |
| Secure MCP Tunnel | Orca MCPへ到達するOpenAIの外向き接続 |
| tunnel-client | Secure MCP Tunnelを張るOpenAI公式クライアント |
| orca-mcp | Orca操作をMCP toolsとして公開する変換層 |

このガイドで解決しない場合は、`status.sh` と `doctor.sh` の結果から対象経路を切り分けます。

最終更新: 2026-09-20
