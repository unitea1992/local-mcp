# Local Dev Hubの機能と設定

DevSpaceからCodexify + Orcaへ移行した後の実用上の対応関係と、個人利用向けに変更している設定をまとめます。

## DevSpaceで使っていた機能

| 用途 | 現在 | 補足 |
| --- | --- | --- |
| ローカルファイル読取 | 対応 | `read_file`, `glob`, `grep`, `tree`, `list_directory` |
| ローカルファイル作成・編集 | 対応 | `write_file`, `apply_patch` |
| ChatGPT添付ファイルの取込 | 対応 | `import_host_file` |
| ローカルファイルをChatGPTへ返す | 対応 | `export_host_file` |
| shell / build / test | 対応 | `exec_command`; 長時間処理はsessionへyield |
| 対話processの継続 | 対応 | `write_stdin`; MCP reconnect後も同じChatでは継続可能 |
| Git status / diff / commit / push / log | 対応 | native Git tools + 必要時はshell |
| ローカルSkill読取 | 対応 | `.agents/skills`, `.codex/skills`, Codex plugins; Claude rootsも有効化 |
| AGENTS.md読取 | 対応 | `get_agent_brief`, `get_project_doc` |
| 複数repoからproject選択 | 対応 | `list_projects` + `set_project_root` |
| 同じChatのworkspace復元 | 対応 | ChatGPT `openai/session` bindingをdiskへ永続化 |
| 新Chatへの引継ぎ | 対応 | exact `resumePath` + `recall` |
| task plan / 長期メモ | 対応 | `update_plan`, `remember`, `recall` |
| worktree作成 | 対応 | Codexify機能は意図的に無効化し、Orcaへ一本化 |
| subagent / 並列agent | 対応 | Orca Run / Task / Dispatch / Worker |
| agent session監督 | 対応 | Orca `worker-show`, `worker-read`, durable Dispatch |
| 他MCPの集約 | 強化 | Codexify catalog modeでschemaを大量公開せず検索・実行 |
| MCP upstream | 対応 | `cua_repl`、`node_repl`、`XServer`をcatalog経由で利用 |

## 主な差分・制約

### ファイル操作の境界

structured filesystem toolsは、そのChatでbindしたproject root内だけを操作します。
これは誤repo編集を避けるための境界です。

`exec_command` 自体は現在ユーザー権限で unrestricted なので、明示的に必要ならproject外のローカルパスも扱えます。
日常作業はnative filesystem toolsを優先し、project外操作だけshellへ落とします。

### process state

長時間commandのsessionはMCP transportを跨いで継続できますが、Codexify server processの再起動までは永続化されません。
再起動を跨ぐ長期作業はOrcaのdurable Run / Task / Dispatchを使います。

### worktree

Codexify自身にもconversation worktree機能がありますが、この環境では使いません。
worktree所有者をOrcaだけにして、同じ論理タスクに2種類のworktree管理が混ざるのを防ぎます。

## デフォルトから変更しているCodexify設定

| 設定 | 標準 | 現在 | 理由 |
| --- | --- | --- | --- |
| `multiProject` | false（quickstart新規ではmulti-project推奨） | true | 1つのConnectorでprojects root配下の全repoを扱うため |
| `workDir` | 起動時指定 / null | projects root | project catalogueのaccess rootを固定するため |
| `worktrees.mode` | auto | never | worktreeをOrcaへ一本化し、二重作成を防ぐため |
| `codexMcp.enabled` | true | true | Codex設定のMCPをLocal Dev Hubへ集約するため |
| `codexMcp.useCli` | true | true | Codex CLIのeffective catalogueも取り込み、plugin由来MCPを自動発見するため |
| `experimental.claudeSkills` | false | true | 将来Claude Code導入時にClaude-owned Skillも自動発見するため |
| `agentChat.enabled` | false | false | ChatGPT + Codexify memory + Orca messagingで足りるため。別Markdown chatを増やさない |
| `experimental.agentTickets` | false | false | downstream response lossを完全観測できず、枝をstrandする可能性があるため |
| `port` | 3000 | 3137 | 既存local serviceとの衝突を避け、現在安定しているlisten portを維持 |
| `openaiTunnel` | null | 有効 | ChatGPTからloopback serverへSecure MCP Tunnelで接続するため |
| `openaiTunnel.clientPath` | 未指定 | 未指定 | Codexify自身のpinned runtimeを使い、Tunnel client互換性をCodexifyへ任せるため |

その他のoutput budget、exec session数、artifact ingress/egress、memory、Skill discovery、ignore規則などは標準値を維持しています。

## 個人利用向けの方針

複数利用者向けの追加ACLは置かず、ChatGPT Workspace + Secure MCP Tunnel + OSユーザー権限を信頼境界にします。
便利さを下げる独自制限は増やさず、誤操作防止はproject binding、Git差分、Orca task ownershipで担保します。
