# local-mcp

ChatGPTからローカル開発環境へ接続する経路と、独立して残すSecure MCP Tunnelの運用を管理するリポジトリです。
個人利用を第一に、独自runtimeを増やさず既存実装を組み合わせます。

現在の開発経路はCodexifyへ集約しています。

~~~mermaid
flowchart LR
    chatgpt[ChatGPT]
    devTunnel[OpenAI Secure MCP Tunnel]
    hub[Local Dev Hub<br/>Codexify]
    tools[File · Git · Shell<br/>Memory · Skills]
    catalog[MCP catalog<br/>cua_repl · node_repl · XServer]
    orca[Orca CLI / Orchestration<br/>worktree · Run · Task · Dispatch · Worker]
    agents[Supervised coding agents<br/>Codex · OMP · OpenCode · others]
    aliTunnel[Separate Secure MCP Tunnel]
    ali[AliNavigator MCP]

    chatgpt --> devTunnel --> hub
    hub --> tools
    hub --> catalog
    hub -->|exec_command| orca --> agents
    chatgpt --> aliTunnel --> ali
~~~

Codexifyはmulti-project modeで `<projects-root>` 配下を扱い、`worktrees.mode=never` で動かします。
並行作業や長時間agent作業のworktreeはOrcaへ一本化し、`<projects-root>/.worktrees/<repo>/<worktree>` に配置します。

## なぜCodexifyへ集約したか

2026-09-27に実機PoCを行い、次を確認しました。

- MCP transportが切れても同じChatのproject bindingとtask memoryを復元できる
- 新しいChatからexact `resumePath` と `recall` で同じcheckoutとtask stateを引き継げる
- 長時間commandは短いMCP callでsession handleを返し、別transportから継続できる
- Codex設定のMCPとCodex CLIのeffective catalogueをcatalog modeへ集約できる
- Codexify経由でOrca Run / Task / Dispatch / Workerを起動・監督・解放できる
- Orca管理worktree上でも同じsupervised workerフローが動く

このため、DevSpaceと自作Orca MCPは通常経路から外しました。
Orcaの再開・idempotency・worker lifecycleはOrca本体へ任せ、local-mcpでは再実装しません。

詳細は [設計](docs/architecture.md)、再構築は [セットアップ](docs/setup.md)、異常時は
[運用ガイド](docs/operations.md) を参照します。

## 日常運用

~~~bash
./scripts/status.sh
./scripts/doctor.sh
./scripts/check.sh
~~~

Orca用のCodexify Skillは次でuser-global skillへリンクします。

~~~bash
./scripts/install-orca-codexify-skill.sh
~~~

## OrcaはCodexifyからCLIで使う

Local Dev Hubのnative toolsは読み取り、テスト、machine config、最終統合に使います。
Git管理repoへ残す変更は原則Orca管理worktreeへ切り出し、長時間・並列agentもOrca Orchestrationへ渡します。

supervised workerはCodexまたはOMPを既定にします。Orca 1.4.212では両方とも
`worker_done → succeeded/completed` まで実機確認済みです。

OpenCode 2.0.18は `worker-start --agent opencode` だと `input_accepted` のまま停滞する場合があります。
一方、`terminal create --command opencode` の後に `terminal wait --for tui-idle` を行い、
そのterminal handleを `worker-start --terminal <handle>` へ渡す手順は `worker_done/succeeded` まで実測成功しました。

Orcaのstatus livenessが `missing_status` の場合もあるため、完了の証明には受理された `worker_done` を使います。

agent固有のadapterはlocal-mcpへ追加しません。新しいagentはOrcaの現在の契約に応じて、
native supervised、既存terminal supervised、unsupervised terminalの順に利用可能性を判定します。

Claude CodeはOrca 1.4.212がnative agent `claude` として明示対応しています。
Hermes AgentもOrca本体のagent catalog / TUI agent selectionでnative `hermes` として対応しています。
どちらも未導入なので、導入後にread-only acceptance testを1回通してsupervised lifecycleを確認します。

現在の実測matrixと追加手順は [Agent互換性](docs/agent-compatibility.md) にまとめています。

DevSpaceからの機能移行状況とCodexify設定の理由は
[Local Dev Hubの機能と設定](docs/local-dev-hub-capabilities.md) にまとめています。

Orcaの契約は更新が速いため、実行前にインストール済みバージョンのbundled skillを確認します。

~~~bash
orca-ide skills get orca-cli
orca-ide skills get orchestration
~~~

新規worktreeは `orca-ide worktree create` で明示作成し、そのexact `path:` selector上で
coordinator terminal、Run、supervised workerを作ります。
`worker-start --worktree new-top-level` のような擬似selectorには依存しません。

## MCP Hub

Codexifyは `~/.codex/config.toml` のMCPを読み込みます。
自動取込はcatalog modeを使い、大きなtool catalogueをChatGPTへ直接展開しません。

現在の開発HubはCodexifyのcatalog upstreamとして `cua_repl`、`node_repl`、`XServer` を取り込んでいます。
`codexMcp.useCli=true` によりCodex CLIのeffective catalogueも加わり、plugin由来MCPもcatalogから利用できます。
AliNavigatorは開発経路とは用途が異なるため、専用Connectorのまま残します。

## AliNavigator Tunnel

AliNavigator MCP本体はalinavigator-api側で管理します。Tunnel作成時のOrganization / Workspace scopeは
CodexifyのTunnelから継承します。

## 秘密情報はGitに入れない

Runtime API keyは `~/.config/local-mcp/runtime-api-key` に置き、Gitへ保存しません。
CodexifyとAliNavigator Tunnelは同じRestricted keyを参照でき、TunnelsのRead + Useだけを持たせます。

AliNavigatorのGateway Access資格情報は `~/.config/local-mcp/alinavigator.env` に分離し、Gitへ保存しません。
Runtime / Admin API keyは現在のユーザー所有・mode 600で管理します。

`tunnel-client` は `config/tunnel-client.version` でバージョンを固定し、
`config/tunnel-client.sha256` に保存した検証済みSHA256と一致する公式release assetだけを導入します。

Tunnel管理用のAdmin API keyは `~/.config/local-mcp/admin-api-key` に置き、
Runtime API keyと同様に現在のユーザー所有・mode 600で管理します。
Admin keyは常駐serviceへ渡さず、Tunnel CRUD時だけ使用します。

## License

[MIT](LICENSE)

最終更新: 2026-09-27
