# 初回セットアップはCodexifyを中心にする

この章は初回セットアップや再構築時に使います。普段の確認は [運用ガイド](operations.md) を参照してください。

## 1. Codexifyを導入する

公式release binaryを使います。

~~~bash
curl -qfsSL https://codexify.dev/install.sh | sh
codexify quickstart
~~~

個人開発環境ではmulti-project modeを選び、普段のプロジェクト群を含むrootを指定します。
Codexify自身にはworktreeを作らせず、worktreeはOrcaへ一本化します。

設定の要点は次です。

~~~json
{
  "workDir": "/absolute/path/to/projects",
  "multiProject": true,
  "worktrees": { "mode": "never" },
  "codexMcp": { "enabled": true, "useCli": false }
}
~~~

`codexMcp.enabled=true` ではCodex user configのMCPを読み込みます。
`useCli=false` はCodex CLI経由の追加探索を行わず、`config.toml` の明示設定だけを取り込む構成です。

## 2. OpenAI Secure MCP Tunnelを設定する

`codexify quickstart` の案内に従い、開発Hub用TunnelとTunnels Read + Useだけを持つruntime keyを設定します。
runtime keyはGitへ保存せず、`file:` または `env:` 参照を使います。

既存のTunnelを移行する場合も、Tunnel IDとruntime keyの参照先だけをCodexify設定へ渡します。
keyの実値を別ファイルへ複製する必要はありません。

設定後はbackground serviceを有効化します。

~~~bash
codexify service install
codexify service status
codexify doctor
~~~

起動直後はupstream MCPとTunnelの初期化に数秒かかることがあります。
`doctor` のhealthだけが一時的に失敗する場合はservice logを確認し、`OpenAI Secure MCP Tunnel: ready` 後に再実行します。

## 3. Orca連携Skillを有効化する

~~~bash
./scripts/install-orca-codexify-skill.sh
~~~

Orcaは独自MCPを挟まず、Codexifyの `exec_command` から `orca-ide` を呼びます。
実行前にインストール済みOrcaのbundled skillを正本として確認します。

~~~bash
orca-ide skills get orca-cli
orca-ide skills get orchestration
~~~

通常の軽い編集はCodexify native toolsで行い、別worktree・長時間・並列agentが必要な場合だけOrcaへ渡します。

## 4. MCP catalogを確認する

Codexify起動時に、取り込んだMCPがcatalogとして表示されることを確認します。
大きなupstreamでもChatGPT側へ全tool schemaを直接公開せず、固定の探索・実行toolから必要なtoolだけ選べます。

この環境ではXServerを開発Hub側へ集約するため、XServer専用Secure MCP Tunnelは不要です。

## 5. AliNavigatorは専用Connectorを維持する

AliNavigatorは開発用Hubとは用途が異なるため、独立したSecure MCP Tunnelを維持します。
MCP本体はalinavigator-api側で管理し、先に同リポジトリでlauncherを用意します。

~~~bash
./mcp/scripts/install-local.sh
~~~

Gateway Access資格情報は `~/.config/local-mcp/alinavigator.env` にmode 600で保存します。

~~~text
ALINAVIGATOR_ACCESS_CLIENT_ID=...
ALINAVIGATOR_ACCESS_CLIENT_SECRET=...
~~~

新しいTunnelはCodexifyの開発Hub Tunnelと同じOrganization / Workspace scopeで作成します。

~~~bash
./scripts/create-secure-mcp-tunnel.sh \
  "AliNavigator MCP" \
  "ChatGPTからAliNavigator APIを利用し、AliExpressとAmazon.co.jpの商品情報を取得するためのローカルMCP"

./scripts/configure-alinavigator-tunnel.sh tunnel_...
~~~

## 6. 確認する

~~~bash
./scripts/check.sh
./scripts/status.sh
./scripts/doctor.sh
~~~

ChatGPT側では開発用Connectorのtool一覧をRefreshし、新しいChatでCodexifyのtoolが見えることを確認します。
古いChatは読み込んだtool schemaを保持するため、切替確認には新しいChatを使います。

最終更新: 2026-09-27
