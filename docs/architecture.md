# DevSpaceは直接接続、OrcaだけSecure MCP Tunnelを使う

## 接続方式は同じ形へ無理に統一しない

local-mcpでは、DevSpaceとOrcaに同じ接続方式を強制しません。
それぞれの既存設計に合う、最も少ない部品で運用できる経路を使います。

~~~text
ChatGPT
  │
  ├─ DevSpace Local
  │      │
  │      ▼
  │   Tailscale Funnel
  │      │
  │      ▼
  │   DevSpace OAuth
  │      │
  │      ▼
  │   127.0.0.1:7676
  │
  └─ Orca MCP
         │
         ▼
     OpenAI Secure MCP Tunnel
         │
         ▼
      tunnel-client
         │ stdio
         ▼
       orca-mcp
         │
         ▼
        Orca
     /    |     \
   OMP OpenCode Codex
~~~

## DevSpaceは既存のOAuth境界をそのまま使う

DevSpaceはHTTP MCPとしてOAuthを内蔵し、Owner passwordによる認可、Bearer token、resource検証を持っています。
ローカルサーバーは `127.0.0.1:7676` にbindし、外部からはTailscale Funnel経由で接続します。

Secure MCP Tunnel経由でも動作することは確認しました。
ただし、その場合はDevSpace OAuthに加えてTunnel側のOAuth discovery、Harpoon、resource alias管理が必要になります。
個人利用では公開経路を1段減らす利点より、設定・障害点・バージョン依存が増える影響を大きく見て採用しませんでした。

DevSpaceの接続方式を再検討する条件は [DevSpaceの接続方式](devspace-auth.md) にまとめています。

## OrcaはSecure MCP Tunnelとの相性がよい

orca-mcpはstdio MCPで、外部向けHTTP listenerを持ちません。
`tunnel-client` がOpenAIへ外向きHTTPS接続を張り、受け取ったMCP要求をローカルのorca-mcpへ渡します。

このためOrca用に公開URL、OAuthサーバー、reverse proxyを追加する必要がありません。
Secure MCP Tunnelを使う価値がDevSpaceより明確です。

常駐runtimeにはTunnelsのRead + Useだけを持つRestricted keyを渡します。
Tunnelの作成・更新に必要なManage権限は常駐プロセスへ渡しません。

## Orca Tunnelはsystemd user serviceで常駐する

Orca Tunnelは `local-mcp-orca-tunnel.service` で管理します。
profileは `tunnel-client init` で生成し、tmux常駐runtimeを作る `runtimes connect` は使いません。

systemdからNVMを読み込んだ後に `tunnel-client run --profile orca-mcp` を起動します。
これによりPC再起動後も自動復旧し、Node.jsの実行環境も普段のNVM設定へ揃えます。

## Orca MCPは既存セッションの引き継ぎを優先する

terminalの一覧、状態、出力本文は既存セッションも含めて読めます。
既存terminalへ入力するときだけ `orca_attach_terminal` で書き込み対象として明示します。

attach対象は、Orcaが `agentIdentity` でOMP / OpenCode / Codexと認識しているterminalです。
誤ってattachした場合は `orca_detach_terminal` で書き込み対象から外せます。
既存terminalの終了は許可せず、orca-mcp自身が起動したterminalだけ閉じられます。

新しいagentはOrcaの `worktree create --agent` を使い、新しいworktreeとまとめて起動します。
既存worktreeへ文字列コマンドでagentを生やしません。

## 個人利用を前提にする

Orca用Tunnelは個人のChatGPT Workspaceへ紐付けます。
orca-mcp単体では利用者ごとのterminal所有権を分離していないため、同じTunnelを複数ユーザーへ共有しません。

DevSpaceもOwner passwordとOAuth tokenを秘密情報として扱います。
Funnel URL自体は秘密情報として扱わず、OAuthが認証境界です。

## 外部依存はforkしない

| 依存 | 扱い |
| --- | --- |
| openai/tunnel-client | 公式配布物を使用 |
| DevSpace | 公式パッケージと既存OAuthを使用 |
| Tailscale Funnel | DevSpaceの公開経路として使用 |
| Orca | 導入済みアプリと `orca-ide` CLIを使用 |
| OMP / OpenCode / Codex | Orcaから起動・再開 |

バージョン依存の設定はCLIの `--help` と公式文書を正本にします。
