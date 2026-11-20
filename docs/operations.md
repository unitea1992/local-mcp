# 日常運用

開発・worktree・長時間エージェント作業はT3 Codeで行います。このリポジトリのCodexify／Orca連携記述は移行前の記録で、現行手順ではありません。

## 状態確認

~~~bash
./scripts/status.sh
~~~

local-mcpが管理するAliNavigator Tunnelの状態などを表示します。T3 Codeの状態はT3 Code内で確認します。

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

## Browser Companionが起きない

~~~bash
systemctl --user status codexify.service
systemctl --user status codexify-display.service
systemctl --user show codexify.service --property=Environment,DropInPaths
tail -50 ~/.codexify/browser/companion.log
~~~

Companionは `codexify.service` の環境を受け継ぎます。
unit定義やdrop-inを直したあとは、`systemctl --user daemon-reload` を流してから `codexify.service` を再起動します。
仮想画面 `:99` と環境変数の設定は [初回セットアップ](setup.md) の「Browser Companionの仮想画面を用意する」を参照してください。

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
`config/tunnel-client.version` を更新する際は、OpenAI公式releaseの `SHA256SUMS.txt` と照合した
Linux amd64 / arm64のSHA256を `config/tunnel-client.sha256` へ同時に反映します。
固定checksumと一致しないassetはインストールされません。

~~~bash
./scripts/install-tunnel-client.sh
./scripts/check.sh
systemctl --user restart local-mcp-alinavigator-tunnel.service
~~~

Codexifyの開発Hub TunnelはCodexify設定の `clientPath` を使います。

最終更新: 2026-10-24
