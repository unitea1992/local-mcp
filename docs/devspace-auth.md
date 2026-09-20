# DevSpaceはTailscale Funnel + OAuthを維持する

この文書は、DevSpaceをSecure MCP Tunnelへ移さない理由を残す判断記録です。
日常運用では読む必要はありません。

## 採用構成は既存の直接接続

DevSpaceは次の構成を維持します。

~~~text
ChatGPT の DevSpace Local
          ↓
    Tailscale Funnel
          ↓
     DevSpace OAuth
          ↓
   127.0.0.1:7676
~~~

`DevSpace Local` もMCP接続です。
`Local` はOrca用Secure MCP Tunnelと区別するための表示名です。

## Secure MCP Tunnel版は動作したが採用しない

2026-09-20に、DevSpaceをOpenAI Secure MCP Tunnel経由で接続し、
OAuthのDynamic Client Registration、Owner password認可、ChatGPTからの接続まで確認しました。

その過程では、Tunnel ClientのHarpoon、OAuth resource alias、
DevSpaceの `oauth.allowedResourceUrls` を追加で管理する必要がありました。
Tunnel Clientのバージョンによって別origin OAuthの設定方法にも差がありました。

DevSpace自身がHTTP + OAuth + public URLを前提に作られているため、
個人利用ではSecure MCP Tunnelを重ねるより既存構成の方が故障点が少なくなります。
そのためDevSpace用Tunnel runtimeは停止し、採用構成から外します。

## セキュリティ境界はDevSpace OAuth

DevSpaceは `127.0.0.1` にbindし、Funnel経由のMCP要求にもOAuthを要求します。
Owner password、access token、refresh tokenは秘密情報として扱います。

DevSpaceのshell toolはローカルユーザー権限で動くため、OAuthを外す独自パッチは作りません。
`allowedHosts` やbind先を広げてOAuthを迂回する構成も採用しません。

## 再検討する条件

次のいずれかが起きた場合だけ、DevSpaceのSecure MCP Tunnel化を再検討します。

- DevSpaceまたはTunnel ClientがOAuth付きローカルMCPを追加設定なしで扱える
- Tailscale Funnelを維持すること自体が運用上の問題になる
- 複数ユーザー利用など、現在と異なる認証境界が必要になる

それまではDevSpaceの構成をOrcaへ合わせるためだけの変更は行いません。

最終更新: 2026-09-20
