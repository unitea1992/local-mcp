# 日常運用はCodexifyを中心に見る

## 状態確認

~~~bash
./scripts/status.sh
~~~

Codexify service、Orca CLI、AliNavigator Tunnelの状態をまとめて確認します。

詳しい診断は次です。

~~~bash
./scripts/doctor.sh
~~~

## Codexifyが接続できない

~~~bash
codexify service status
codexify service logs
codexify doctor
curl -fsS http://127.0.0.1:3137/health
~~~

起動直後はMCP aggregationとSecure MCP Tunnelの準備中でhealthが一時的に503になる場合があります。
service logでTunnel readyまで進んでいるか確認してから再診断します。

## ChatGPT側で古いtoolが見える

Connectorのtool一覧は既存Chatへ即時反映されません。
ChatGPT Settingsで開発用ConnectorをRefreshし、新しいChatを開始します。

同じChatのMCP transport再接続やCodexify再起動ではproject bindingが復元されます。
新しいChatへ移る場合はPrepare handoffでexact `resumePath` を引き継ぎ、workspace選択後に `recall` します。

## 長時間commandを扱う

Codexifyの `exec_command` は長い処理をsessionへyieldできます。
session IDが返ったら同じ処理を起動し直さず、`write_stdin` でpollします。

ChatGPTの1ターン寿命そのものは保証できないため、長い作業ではフェーズ境界でplanと必要なnoteを保存します。
次フェーズも長い場合は一度進捗をユーザーへ返し、次ターンから続行します。

## Orcaで長時間agentを動かす

まず現在の契約を確認します。

~~~bash
orca-ide skills get orca-cli
orca-ide skills get orchestration
~~~

基本は専用coordinator terminalとRunを作り、supervised workerを起動します。

~~~text
exact worktree
  → coordinator terminal
  → Run
  → Task / Dispatch / Worker
  → worker-show / worker-read
  → worker-release
~~~

新規worktreeが必要なら `orca-ide worktree create` を先に実行し、返されたexact pathを使います。
作成結果が不明な時は同じ名前で別worktreeを作らず、まず `worktree list` とOrchestration stateを確認します。

Orca mutationのresponseが不明な場合は、現在のCLIが返すrequest IDと `--retry-request` の契約に従います。

## AliNavigatorだけ接続できない

~~~bash
systemctl --user status local-mcp-alinavigator-tunnel.service
journalctl --user -u local-mcp-alinavigator-tunnel.service -n 100 --no-pager
tunnel-client doctor --profile-dir "$HOME/.config/local-mcp/tunnel-profiles" --profile alinavigator-mcp
~~~

Gateway Access資格情報は `~/.config/local-mcp/alinavigator.env`、profileは
`~/.config/local-mcp/tunnel-profiles/alinavigator-mcp.yaml` にあります。
MCP launcherとprobeはalinavigator-api側で管理します。

profileを再作成する場合は次を使います。

~~~bash
./scripts/configure-alinavigator-tunnel.sh tunnel_...
~~~

## Tunnelを追加する

新しい専用TunnelはCodexifyの開発Hub TunnelからOrganization / Workspace scopeを継承します。

~~~bash
./scripts/create-secure-mcp-tunnel.sh "<name>" "<description>"
~~~

別の既存Tunnelをscope正本にする場合だけ第3引数へTunnel IDを指定できます。

## tunnel-clientを更新する

AliNavigatorのstandalone Tunnelではlocal-mcp管理のtunnel-clientを使います。

~~~bash
./scripts/install-tunnel-client.sh
./scripts/check.sh
systemctl --user restart local-mcp-alinavigator-tunnel.service
~~~

Codexifyの開発Hub TunnelはCodexify設定の `clientPath` を使います。

最終更新: 2026-09-27
