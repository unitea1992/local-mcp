# DevSpaceのOAuthは残し、公開範囲だけ最小化する

この文書は、DevSpace MCPの認証構成を変更するときの判断基準です。
通常運用では読む必要はありません。
「なぜFunnelがまだ残っているか」「最終的に何を公開するか」が分からなくなったときに参照します。

## 結論はOAuth維持、Funnelは認可画面だけ

最終形では、DevSpaceのMCP本体をTailscale Funnelから外します。
ChatGPTからのMCP通信はSecure MCP Tunnel経由でlocalhostへ接続します。

ただしDevSpace独自OAuthは維持します。
ブラウザでOwner passwordを入力する認可画面だけはSecure MCP Tunnelが代理公開しないため、
Tailscale Funnelを `/authorize` 専用の公開入口として残します。

~~~text
ChatGPT
  │
  ├─ MCP / OAuth metadata / register / token / revoke
  │        ↓
  │   Secure MCP Tunnel
  │        ↓
  │   127.0.0.1:7676
  │        ↓
  │      DevSpace
  │
  └─ ブラウザ認可
           ↓
     Tailscale Funnel
           ↓
       /authorize
           ↓
      DevSpace OAuth
~~~

## OAuthを外す案はDevSpace本体の改造が必要なので採用しない

「Secure MCP TunnelとPersonal ChatGPT Workspaceを認証境界にして、
DevSpace側のOAuthを外す」案も検討しました。

現行DevSpaceでは採用しません。

DevSpace 1.1.0-beta.4の設定スキーマにはOAuthを無効化する項目がありません。
サーバー実装も起動時にOAuth provider、OAuth router、Bearer認証を常に作成します。
現在のmainブランチの設定資料も、Owner passwordによるOAuthを前提にしています。

OAuthを外すにはDevSpaceをforkするか、配布済みコードへ独自パッチを当てる必要があります。
この方法には次の問題があります。

- DevSpace更新のたびに認証パッチを追従する必要がある
- `127.0.0.1` のbind設定が将来変わった場合、認証なしの高権限MCPが露出する
- 別のreverse proxyやFunnel設定を誤った場合も、OAuthが最後の防御にならない
- DevSpace公式のセキュリティモデルから外れる

DevSpaceのshell toolはローカルユーザー権限で動くため、
「認証なしでも今はloopbackだから大丈夫」という条件に依存させません。
保守性と障害時の安全性を優先し、DevSpace OAuthを残します。

## この構成で崩してはいけない安全条件

最終構成では、次を安全条件として扱います。

- DevSpaceは `127.0.0.1` にだけbindする
- ChatGPTからMCP本体へ入る経路はSecure MCP Tunnelだけにする
- Tailscale Funnelは認可専用proxyだけを公開し、DevSpaceへ直接向けない
- 認可専用proxyは `GET /authorize` と `POST /authorize` 以外を拒否する
- DevSpaceのOwner passwordとOAuth tokenはGitやログへ残さない
- Tunnel ClientのRuntime API keyはTunnelsのRead + Useだけを持たせる
- Tunnelは個人用のChatGPT Workspaceにだけ紐付ける

このうち1つでも崩れる変更を行う場合は、先にセキュリティレビューをやり直します。

## Secure MCP Tunnelが担当できるOAuth経路

OpenAI Secure MCP Tunnelは、OAuth保護されたHTTP MCPをサポートしています。
MCP通信のAuthorization headerをDevSpaceへ転送し、OAuth discoveryもローカル側で実行します。

OAuthのうち、Tunnel側で中継できるものとできないものを分けます。

| OAuth処理 | 経路 |
| --- | --- |
| Protected Resource Metadata | Secure MCP Tunnel |
| Authorization Server Metadata | Secure MCP Tunnelが取得 |
| Dynamic Client Registration | Secure MCP Tunnel / Harpoon |
| Token exchange | Secure MCP Tunnel / Harpoon |
| Token revocation | Secure MCP Tunnel / Harpoon |
| ブラウザのAuthorization endpoint | upstreamへ直接アクセス |

最後のAuthorization endpointだけは、ブラウザから到達できる公開HTTPS URLが必要です。

## 現在のFunnel全体公開は移行中だけ

2026-09-20時点では、`tunnel-client 0.0.14` のmanaged runtimeから
DevSpaceのlocalhost MCPと別originのOAuth serverを扱うと、OAuth用Harpoon targetを
管理しづらい制約があります。

現在は接続検証を優先し、次の暫定経路にしています。

~~~text
ChatGPT
  ↓
Secure MCP Tunnel
  ↓
Tailscale Funnel
  ↓
DevSpace
~~~

これは最終構成ではありません。
既存Funnel + DevSpace OAuthより公開範囲を広げてはいませんが、
MCP本体がInternetから到達可能な状態は残っています。

## Funnelを認可画面だけへ絞る条件

次の条件をすべて満たしてから、Funnelの公開範囲を変更します。

1. ChatGPTのDevSpace MCP ConnectorでOAuthを完了できる
2. Secure MCP Tunnel経由で `tools/list` と実際のtool callが成功する
3. Tunnel ClientからMCP本体を `http://127.0.0.1:7676/mcp` へ直接接続できる
4. 別originのOAuth metadata / token経路がHarpoon経由で正常に動く
5. 公開入口が `/authorize` のGET/POST以外を拒否する
6. Funnel側から `/mcp`、`/token`、`/register`、`/revoke`、well-known metadataへ到達できない

条件3と4は、導入中のTunnel Clientが `mcp.oauth_trusted_origins` を正式サポートした段階で再評価します。
旧バージョン向けのHarpoon host classifierを独自運用してmanaged runtimeを分岐させる方法もありますが、
保守経路が二重になるため現時点では採用しません。

## 公開入口はdeny-by-defaultにする

Tailscale FunnelをDevSpaceへ直接向けたままpathだけで制御しません。
認可専用の小さなreverse proxyをloopbackで動かし、Funnelはそのproxyだけを公開する構成を予定します。

proxyが許可するのは次の2種類だけです。

- `GET /authorize`
- `POST /authorize`

それ以外は404または明示的な拒否を返します。
DevSpaceの認可HTMLはCSSをページ内に持ち、フォームも同じURLへPOSTするため、
通常の認可フローで追加assetを公開する必要はありません。

proxyの実装とFunnelの切り替えは、DevSpace ConnectorのOAuth疎通確認後に行います。

## 前提が変わったら再検討する

次のいずれかが起きた場合は、この判断を見直します。

- DevSpace本体が公式に「OAuthなし + loopback限定」モードを提供した
- Secure MCP TunnelがブラウザのAuthorization endpointも安全に中継するようになった
- DevSpaceが外部IdPを正式サポートし、公開認可画面をローカルPCに置く必要がなくなった

それまでは「DevSpace OAuthを維持し、公開面だけ最小化する」を基準にします。

最終更新: 2026-09-20
