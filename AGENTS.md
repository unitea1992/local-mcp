# local-mcp 作業ガイド

- ローカルMCPとSecure MCP Tunnelの設定・運用をまとめて管理する。
- OpenAIの `tunnel-client`、DevSpace、Orca本体はfork・vendorしない。
- APIキー、OAuthトークン、パスワードなどの秘密値はGitへ保存しない。
- Orca MCPでは任意シェル実行を公開せず、許可したOrca CLI操作だけをツールとして公開する。
- 日本語ドキュメントはnatural-japaneseの方針で書き、Markdownはrumdlで整形・検査する。
