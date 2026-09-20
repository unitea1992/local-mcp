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

ローカルで生成した実プロファイルは profiles/local/ に置きます。
このディレクトリはGit管理外です。
共有したい内容は、秘密情報を除いた説明や生成手順として profiles/README.md に残します。

## DevSpaceをSecure MCP Tunnelへ移したい

DevSpaceは現在OAuthを使っています。
HTTP/OAuth向けの sample_mcp_with_dcr からプロファイルを生成し、
まずSecure MCP Tunnel経由でtool discoveryと実行が通ること、その後ChatGPTからOAuthを含めて再接続できることを確認します。

既存のTailscale Funnel停止は最後です。
Secure MCP Tunnel経由で同じ操作ができると確認するまでは残します。

## Orca MCPを使いたい

apps/orca-mcp をビルドすると、stdio MCPとして起動できます。

~~~bash
pnpm install
pnpm build
node apps/orca-mcp/dist/index.js
~~~

通常は人間が直接起動するのではなく、Secure MCP Tunnelから子プロセスとして起動します。

## Secure MCP Tunnelを再起動したら、以前のagentはOrcaに残る

orca-mcpは、自分が起動したOMP / OpenCodeだけに読み書きできます。
この管理情報はMCPプロセスの再起動をまたいで引き継ぎません。

そのためSecure MCP Tunnelを再起動した後も以前のagent terminalはOrcaに残りますが、
ChatGPTからそのterminalへ勝手に再接続することはありません。
続きが必要ならOrca側で状態を確認し、新しいagentをChatGPTから起動するか、人間が既存terminalを引き継ぎます。

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
