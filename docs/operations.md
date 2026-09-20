# 普段はstatus、異常時はdoctorを見る

このガイドは日常運用の逆引き用です。
初回だけREADMEと設計を読み、それ以降は必要な項目だけ参照してください。

## 今の状態を知りたい → status.sh

~~~bash
./scripts/status.sh
~~~

Node.js、pnpm、Orca、DevSpace、tunnel-client、Tailscale Funnelの状態をまとめて確認します。
秘密情報の値は表示しません。

## 何か動かない → doctor.sh

~~~bash
./scripts/doctor.sh
~~~

DevSpaceの診断、OrcaのCLI疎通、Secure MCP Tunnelクライアントの有無を確認します。
tunnel-client のプロファイルがまだない段階では、その旨を表示して終了します。

## 変更後に壊していないか確認したい → check.sh

~~~bash
./scripts/check.sh
~~~

依存関係が導入済みならTypeScriptの型検査、ビルド、テストを実行し、最後に rumdl でMarkdownを確認します。

## Secure MCP Tunnelを追加したい

まずこのリポジトリで検証済みの tunnel-client を導入します。
このリポジトリのスクリプトはSHA256を検証し、今回不要なCloudflare companionはインストールしません。

~~~bash
./scripts/install-tunnel-client.sh
tunnel-client --version
~~~

プロファイル形式は手書きで固定せず、導入した tunnel-client の init とサンプルを正本にします。
新しいリリースへ更新するときは、先に動作確認してから `config/tunnel-client.version` を更新します。

~~~bash
tunnel-client help quickstart
tunnel-client profiles samples list
~~~

ローカルで生成した実プロファイルは `~/.config/local-mcp/tunnel-profiles/` に置きます。
リポジトリ外なのでGit管理されません。
共有したい内容は、秘密情報を除いた説明や生成手順として profiles/README.md に残します。

## DevSpaceをSecure MCP Tunnelへ移したい

DevSpaceは現在OAuthを使っています。
OAuthは外しません。
DevSpace本体にOAuthなしモードがなく、独自パッチで外すと高権限MCPの誤公開リスクと保守コストが増えるためです。

現在は移行中のため、`devspace-mcp` の上流も既存Tailscale Funnelです。
ChatGPT ConnectorでOAuthとtool callを確認した後、MCP本体をlocalhostへ戻します。

最終的なFunnelはDevSpace全体を公開せず、`/authorize` のGET/POSTだけを通す認可専用入口にします。
現在地と切り替え条件は [DevSpaceの認証設計](devspace-auth.md) を確認してください。

OAuth認可で `Invalid or missing OAuth resource` が出た場合は、
まずDevSpaceの `oauth.allowedResourceUrls` を確認します。
ChatGPTが使うTunnel MCP resource URLが完全一致で登録されている必要があります。
host全体やワイルドカードでは許可しません。

## Orca MCPを使いたい

apps/orca-mcp をビルドすると、stdio MCPとして起動できます。

~~~bash
pnpm install
pnpm build
node apps/orca-mcp/dist/index.js
~~~

通常は人間が直接起動するのではなく、Secure MCP Tunnelから子プロセスとして起動します。

新しい作業をChatGPT側から始める場合は、`orca_create_agent_worktree` を使います。
Orcaのagent-aware launcherで新しいworktreeとOMP / OpenCode / Codexをまとめて作るため、
Orcaに設定しているagent commandや既定引数を迂回しません。

既存worktreeで途中まで進んでいる作業は、新しくagentを生やさず既存terminalを読み、
必要なら `orca_attach_terminal` で引き継ぎます。

現行Orcaには、既存worktreeへagent-awareに新しいterminalを追加するCLIがありません。
`terminal create --command` はOrcaのagent commandや既定引数を迂回するため、orca-mcpでは使いません。
同じworktreeへ新しいagentが必要な場合はOrca側で起動し、そのterminalをChatGPTからattachします。

## Secure MCP Tunnelを再起動したら、既存agentを読み直してattachする

orca-mcpは既存terminalの出力も読めます。
ただし、書き込み対象としてattachした情報はMCPプロセスの再起動をまたいで引き継ぎません。

Secure MCP Tunnelを再起動した後も、以前のagent terminalはOrcaに残ります。
ChatGPTから出力を読み直し、続きが必要なterminalだけ `orca_attach_terminal` で再度引き継ぎます。

## Tunnel名は表示用と内部用を分ける

人間向けの表示名は `Orca MCP` / `DevSpace MCP` です。
コマンドで使うruntime aliasとprofileは `orca-mcp` / `devspace-mcp` にします。
日常の確認も短い内部名を使います。

~~~bash
tunnel-client runtimes status orca-mcp --json
tunnel-client runtimes status devspace-mcp --json
tunnel-client doctor --profile-dir "$HOME/.config/local-mcp/tunnel-profiles" --profile devspace-mcp --explain
~~~

## 用語

| 用語 | このリポジトリでの意味 |
| --- | --- |
| Secure MCP Tunnel | OpenAIからローカルMCPへ到達するための外向き接続 |
| tunnel-client | Secure MCP Tunnelを張るOpenAI公式クライアント |
| DevSpace | 汎用的なローカル操作を担当するMCP |
| Orca | 普段の開発画面とterminalを管理するアプリ |
| orca-mcp | ChatGPT向けにOrca操作を限定公開する自作MCP |

このガイドで解決しない場合は、まず ./scripts/status.sh と ./scripts/doctor.sh を実行します。
ChatGPTへ渡すときは、API key、OAuth token、パスワードが含まれていないことを確認してから共有します。

最終更新: 2026-09-20
