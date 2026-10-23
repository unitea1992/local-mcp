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
  "codexMcp": { "enabled": true, "useCli": true },
  "experimental": { "claudeSkills": true }
}
~~~

`codexMcp.enabled=true` ではCodex user configのMCPを読み込みます。
`useCli=true` ではCodex CLIのeffective catalogueも取り込み、plugin由来MCPもcatalog modeへ集約します。
`experimental.claudeSkills=true` は将来Claude Codeを導入した際にClaude-owned skill rootsも発見できるようにします。

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

Git管理repoへ残す変更は原則Orca管理worktreeで行います。Codexify native toolsは読み取り、テスト、machine config、最終統合に使います。

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

## 6. Browser Companionの仮想画面を用意する

Browser CompanionはCodexifyが起こしたプロセスの環境を受け継ぎます。
`codexify.service` の環境に `DISPLAY` がないとRDPなしではCompanionが起きず、
ユーザーのsystemd環境にはGNOMEセッションから `XDG_SESSION_TYPE=wayland` が残るため
Companion（Electron）はWaylandを選んで失敗します。
そこで仮想画面をCodexify専用に `:99` ひとつ立てて渡し、X11を明示します。
`:98` はAliNavigator側の仮想画面のため、共有せず分けます。

仮想画面は `~/.config/systemd/user/codexify-display.service` に置きます。

~~~ini
[Unit]
Description=Codexify: virtual display :99 for the browser companion

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
~~~

環境変数は `~/.config/systemd/user/codexify.service.d/display.conf` へのdrop-inで渡します。
`Wants` / `After` により、Companionが起きる前に画面が立つようcodexify.serviceから呼ばれます。

~~~ini
# Browser Companion は起こしたプロセスの環境を受け継ぐ。RDP なしでも立て直せるよう、専用の仮想画面 :99 を渡す。
# ユーザーの systemd には GNOME のセッションから XDG_SESSION_TYPE=wayland が残るため、X11 を明示する。
[Unit]
Wants=codexify-display.service
After=codexify-display.service

[Service]
Environment=DISPLAY=:99
Environment=XDG_SESSION_TYPE=x11
Environment=WAYLAND_DISPLAY=
# 送信の段ごとの記録（上流 Issue #12 の調査用。直ったら消す）
Environment=CODEXIFY_BROWSER_TRACE_SUBMISSION=1
~~~

設定を反映します。

~~~bash
systemctl --user daemon-reload
systemctl --user enable --now codexify-display.service
systemctl --user status codexify-display.service
~~~

`codexify.service` は次の起動からdrop-inの環境変数を読みます。
既に `codexify.service` を起動済みのときは、`systemctl --user restart codexify.service` を行ってから確認します。
Companionがreadyになることは `~/.codexify/browser/companion.log` で確認してください。
`CODEXIFY_BROWSER_TRACE_SUBMISSION=1` は送信の段階をそれぞれ記録するもので、
上流の不具合 [devnoname120/codexify#12](https://github.com/devnoname120/codexify/issues/12) の調査用です。
このIssueが直ったらdrop-inのこの行を消します。

## 7. 確認する

~~~bash
./scripts/check.sh
./scripts/status.sh
./scripts/doctor.sh
~~~

ChatGPT側では開発用Connectorのtool一覧をRefreshし、新しいChatでCodexifyのtoolが見えることを確認します。
古いChatは読み込んだtool schemaを保持するため、切替確認には新しいChatを使います。

最終更新: 2026-10-24
