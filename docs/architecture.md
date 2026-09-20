# MCP本体は公開せず、DevSpaceの認可画面だけ外へ出す

## DevSpaceは汎用、Orcaはコーディング専用に分ける

local-mcp は、ChatGPTからローカル開発環境を操作するための接続・運用基盤です。
公開URLを増やすより、ローカルMCPをOpenAI Secure MCP Tunnelへ接続する構成を優先します。

DevSpaceとOrcaの役割は分けます。
DevSpaceはファイル、シェル、Gitなどを扱う汎用経路です。
Orca側は普段使っているterminalとコーディングハーネスを操作する専門経路にします。

## ChatGPTからはSecure MCP Tunnel経由で接続する

~~~text
ChatGPT Web / Mobile / Desktop
            │
            ▼
   OpenAI Secure MCP Tunnel
       │             │
       ▼             ▼
    DevSpace       orca-mcp
  127.0.0.1           │
       │               ▼
       │             Orca
       │           /      \
       │         OMP    OpenCode
       │
       └── OAuthの認可画面だけ
             Tailscale Funnel
                 │
                 ▼
             /authorize
~~~

tunnel-client はOpenAI公式の外部依存として利用し、このリポジトリへソースを取り込みません。
プロファイル、起動方法、診断方法だけを管理します。
通常のSecure MCP TunnelはOpenAI APIへの外向きHTTPS接続だけを使います。
配布物に含まれるCloudflare companionは今回の構成では使いません。

常駐runtimeにはTunnelsのRead + Useだけを持つRestricted keyを渡します。
Tunnelの作成や更新に必要なManage権限は、常駐runtimeから分離します。

この構成は個人利用を前提にします。
Orca用Tunnelを複数ユーザーのWorkspaceへ共有すると、orca-mcp単体ではterminal handleの所有者を利用者ごとに分離できません。
共有利用へ広げる場合は、利用者単位の認可を追加するまで同じruntimeを使い回しません。

## Orca MCPは既存セッションをレビューして引き継げる

DevSpaceには汎用的なシェル実行があります。
そのためOrca MCPだけを厳しく制限しても、環境全体の権限分離にはなりません。
Orca MCPでは、普段の開発フローを邪魔しないことと誤操作を防ぐことの両方を優先します。

terminalの一覧、状態、出力本文は既存セッションも含めて読めます。
これにより、Orca側で途中まで進めたOMP / OpenCodeの作業をChatGPTからレビューできます。

既存terminalへ入力するときは `orca_attach_terminal` で明示的に引き継ぎます。
attach後は追加指示を送り、待機状態を確認できます。
attachできるのは、Orcaが `agentIdentity` でOMP / OpenCode / Codexと認識しているterminalだけです。
手動でOpenCodeを起動した場合もOrca 1.4.205で `agentIdentity` が付くことを確認しています。
誤ってattachした場合は `orca_detach_terminal` で書き込み対象から外せます。
既存terminalの終了だけは許可せず、orca-mcp自身が起動したterminalに限定します。
別のterminalを誤って閉じる事故を避けるためです。

新しいagentは、既存worktreeへ文字列コマンドで起動しません。
Orcaの `worktree create --agent` を使い、新しいworktreeとagentをまとめて作成します。
これにより、Orcaに設定したagent command、既定引数、環境変数をそのまま利用できます。
対象はOMP / OpenCode / Codexです。

orca-mcpが書き込み対象としてattachしたterminal一覧はメモリ上だけに持ちます。
Orca MCPやSecure MCP Tunnelが再起動しても、実行中のOMP / OpenCodeはOrca側に残ります。
再起動後は出力を読み直して、必要なterminalだけ再度attachします。

## 表示名と内部名は短く分ける

ChatGPTやOpenAI Platformで人間が見るTunnel名は `Orca MCP` と `DevSpace MCP` にします。
ローカルruntime aliasとprofileは、それぞれ `orca-mcp` と `devspace-mcp` に揃えます。

リポジトリ名がすでに `local-mcp` なので、内部名へさらに `local-mcp-` を重ねる必要はありません。

## ユーザーとChatGPTが同じterminalを見る

Orca MCPは別の隠れたハーネスを立ち上げるのではなく、Orcaが管理するterminalを読み書きします。
ChatGPTがOMPやOpenCodeへ送った指示と、その結果をOrca側から確認できます。

この方式ではOrcaが作業画面、Secure MCP Tunnelが接続経路、orca-mcpが権限を絞る変換層になります。

## DevSpaceのOAuthは外さない

DevSpace 1.1.0-beta.4では、OAuthは任意機能ではありません。
設定スキーマに無効化項目がなく、サーバー起動時にOAuth providerとBearer認証が常に組み込まれます。
現在のmainブランチの設定資料も同じ前提です。

OAuthを外すにはDevSpace本体へ独自パッチが必要です。
DevSpaceはshellやファイル操作をローカルユーザー権限で実行できるため、
認証なしモードを独自追加すると、将来の設定変更や誤公開がそのまま高権限のリモート操作につながります。
このリポジトリではDevSpace本体をforkしない方針とも合わないため、OAuth無効化案は採用しません。

詳しい検討結果と移行条件は [DevSpaceの認証設計](devspace-auth.md) を正本にします。

## DevSpaceの最終構成ではMCP本体をlocalhostへ戻す

OpenAI Secure MCP Tunnelは、OAuth保護されたMCPの
Protected Resource Metadata、registration、token、revocationを中継できます。
一方、ブラウザで開く `authorization_endpoint` は中継しません。

そのため最終構成は次の分担にします。

| 経路 | 公開範囲 |
| --- | --- |
| ChatGPT → DevSpace MCP | Secure MCP Tunnel → `127.0.0.1:7676/mcp` |
| OAuth metadata / register / token / revoke | Secure MCP Tunnel / Harpoon |
| OAuth認可画面 | Tailscale Funnel → `/authorize` のGET/POSTだけ |
| DevSpaceのその他のHTTP route | Internetへ公開しない |

認可画面はDevSpace自身がHTMLを返し、フォームも同じ `/authorize` へPOSTします。
外部assetを必要としないため、公開面をこのrouteへ限定できます。

## 現在はFunnel全体を上流にする暫定構成

2026-09-20時点の `tunnel-client 0.0.14` では、
managed runtimeの `runtimes connect` が生成するprofileに
別originのOAuth trust設定を保持できません。
そのため現在の `devspace-mcp` は、暫定的に既存Funnelの `/mcp` を上流にしています。

これは接続確認のための移行状態です。
DevSpaceの公開範囲を増やしたものではありませんが、MCP本体も引き続きFunnelから到達できるため、
最終状態として固定しません。

## 外部依存は改造せず追従する

| 依存 | 扱い |
| --- | --- |
| openai/tunnel-client | 公式配布物を使用。forkしない |
| DevSpace | β版の公式パッケージを使用。forkしない |
| Orca | 導入済みアプリと orca-ide CLIを使用 |
| OMP / OpenCode | Orcaから起動・再開する |

バージョン依存のコマンドや設定形式は、固定した説明を増やすより、各CLIの --help と公式文書を正本にします。
