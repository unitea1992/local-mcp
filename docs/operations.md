# 普段はstatus、異常時だけ個別経路を見る

このガイドは日常運用の逆引き用です。
構成全体を確認したい場合は [設計](architecture.md) を参照してください。

## 今の状態を確認したい → status.sh

~~~bash
./scripts/status.sh
~~~

DevSpace、Orca、tunnel-client、Orca / XServer Tunnel service、Tailscale Funnelの状態をまとめて確認します。
秘密情報の値は表示しません。

## 何か動かない → doctor.sh

~~~bash
./scripts/doctor.sh
~~~

DevSpaceの診断、Orca CLI、Secure MCP Tunnel profiles、Orca / XServer Tunnel serviceを確認します。

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
Tunnel管理用Admin API keyは `~/.config/local-mcp/admin-api-key` にあります。

新しいTunnelを作る場合は、Organization / Workspace IDを手入力せず、
既存Orca profileからscopeを継承する共通スクリプトを使います。

~~~bash
./scripts/create-secure-mcp-tunnel.sh "<name>" "<description>"
~~~

`description` はChatGPT / Platform上でそのまま表示されるため、日本語で記述します。

Tunnelの作成・更新・削除に使うAdmin API keyは
`~/.config/local-mcp/admin-api-key` にあります。
Runtime keyとは分離し、常駐serviceへは渡しません。

## XServer MCPだけ接続できない → XServer Tunnelを見る

~~~bash
systemctl --user status local-mcp-xserver-tunnel.service
journalctl --user -u local-mcp-xserver-tunnel.service -n 100 --no-pager
tunnel-client doctor --profile-dir "$HOME/.config/local-mcp/tunnel-profiles" --profile xserver-mcp
~~~

serviceを入れ直す場合は次を実行します。

~~~bash
./scripts/install-xserver-tunnel-service.sh
~~~

profileは `~/.config/local-mcp/tunnel-profiles/xserver-mcp.yaml` です。
Runtime API keyとorganization contextはOrca Tunnelと共用します。

ChatGPT側で `tunnel_active_organization_required` が出る場合は、
まず `doctor.sh` でローカルruntimeのorganization contextが設定済みか確認します。
ローカル側が正常でもChatGPTから同じエラーになる類似事象は、
2026-09-20時点でopenai/tunnel-clientのIssue #60として報告されています。
この環境ではChatGPT側のOrca MCP設定からOrganization選択だけを外し、
Workspace紐付けを残して保存すると実呼び出しが復旧しました。
Platform APIで取得するTunnel metadata自体はOrganization + Workspaceの両方を保持したままで、
ローカルruntimeの `CONTROL_PLANE_ORGANIZATION_ID` も引き続き必要です。
そのため同じエラー時はローカルorganization contextを消さず、
まずChatGPT側ConnectorのOrganization選択を確認します。

## AliNavigator MCPだけ接続できない → AliNavigator Tunnelを見る

~~~bash
systemctl --user status local-mcp-alinavigator-tunnel.service
journalctl --user -u local-mcp-alinavigator-tunnel.service -n 100 --no-pager
tunnel-client doctor --profile-dir "$HOME/.config/local-mcp/tunnel-profiles" --profile alinavigator-mcp
~~~

profileは ~/.config/local-mcp/tunnel-profiles/alinavigator-mcp.yaml、Gateway Access資格情報は
~/.config/local-mcp/alinavigator.env にあります。
MCP本体とlauncherは alinavigator-api 側で管理します。
doctorは資格情報のmode、stdio/tools discovery、Gatewayのhealth tool、Tunnel serviceを個別に確認します。

launcherがない場合は alinavigator-api で ./mcp/scripts/install-local.sh を実行し、profileを作り直す場合は次を使います。

~~~bash
./scripts/configure-alinavigator-tunnel.sh tunnel_...
~~~

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

OMP / OpenCode / CodexのようなTUIの現在表示を確認する場合は、
`orca_read_terminal` に `screen=true` を指定します。
通常の蓄積ログを追う場合は既定のstream読み取りを使い、cursorで差分を取得します。
`screen=true` とcursorは同時指定しません。

Secure MCP Tunnelやorca-mcpが再起動してもOrcaのterminalは残ります。
再起動後は対象terminalを読み直し、必要なら再度attachします。

## 新しいOrca agentを起動する

`orca_create_agent_worktree` を使い、worktreeとOMP / OpenCode / Codexをまとめて作ります。
既存worktreeに新しいagentが必要な場合はOrca側から起動し、そのterminalをChatGPTからattachします。

Orca 1.4.205 + OpenCode 2.0.11では、Orca生成のOpenCode status pluginが旧契約のため
`1 plugin failed /plugins` と表示される既知事象があります。
OpenCode本体の起動、terminal read/send、TUI待機は実機で動作確認済みです。
生成pluginへ手修正は入れず、Orca upstreamの修正を待ちます。

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

最終更新: 2026-09-25
