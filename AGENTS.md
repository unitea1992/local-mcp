# local-mcp 作業ガイド

- ChatGPTのローカル開発経路と、独立して残すSecure MCP Tunnelの設定・運用を管理する。
- 開発用の正規フロントはCodexify、長時間agent実行はOrca CLI / Orchestrationを使う。
- OpenAIの `tunnel-client`、Codexify、Orca本体はfork・vendorしない。
- APIキー、OAuthトークン、パスワードなどの秘密値はGitへ保存しない。
- 秘密情報の置き場所は所有元で決める。`local-mcp` 自身のRuntime / Admin keyは `~/.config/local-mcp/`、
  サービス固有の資格情報は `~/projects/.secrets/<repo>/` を正本にする。
  `local-mcp` からサービス固有secretが必要な場合は複製せず参照を作る。
- Secure MCP Tunnelの説明文は日本語で統一する。固有名詞や製品名は原表記を維持してよい。
- Orca操作は独自MCPへ再実装せず、インストール済みOrcaのCLIとbundled skillを正本にする。
- Codexifyのupstream MCPはCodex設定からcatalog modeで集約し、専用Connectorが必要なサービスだけ分離する。
- 日本語ドキュメントは自然な日本語で書く。Markdownを変更した場合はリポジトリのrumdl設定を使う。
