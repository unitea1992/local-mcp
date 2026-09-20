# local-mcp

ローカルMCPとSecure MCP Tunnelの設定・運用をまとめて管理するリポジトリです。

最初の対象はDevSpaceとOrcaです。
DevSpaceは汎用的なローカル操作、Orcaは普段の開発画面とOMP・OpenCodeの操作に使います。
ChatGPTからローカル環境へ入る経路は、最終的にOpenAI Secure MCP Tunnelへ寄せます。

## 最初はREADMEと設計だけ読めばよい

初回はこのREADMEと [設計](docs/architecture.md) まで読めば十分です。
日常運用で困ったときは [運用ガイド](docs/operations.md) を参照してください。

~~~text
ChatGPT
   │
   ├─ Secure MCP Tunnel ─ DevSpace
   │
   └─ Secure MCP Tunnel ─ orca-mcp ─ Orca ─ OMP / OpenCode
~~~

現時点ではローカル側のPoCまで完了しています。
既存のTailscale Funnelは停止せず、Secure MCP Tunnelの疎通とDevSpaceのOAuthを確認してから切り替えます。

## 役割ごとに置き場所を分ける

| パス | 役割 |
| --- | --- |
| apps/orca-mcp/ | ChatGPTからOrcaを操作する自作MCP |
| profiles/ | Secure MCP Tunnelのプロファイル管理方針とローカル設定置き場 |
| scripts/ | 状態確認や診断など、人間向けの運用コマンド |
| docs/ | 設計、運用、移行手順 |

## 日常運用は4コマンドに寄せる

~~~bash
./scripts/install-tunnel-client.sh
./scripts/status.sh
./scripts/doctor.sh
./scripts/check.sh
~~~

install-tunnel-client.sh はこのリポジトリで検証済みのOpenAI公式リリースをSHA256で確認し、
tunnel-client本体だけを導入します。
Cloudflare companionは今回使わないため導入しません。
status.sh は依存ツールと現在の状態を確認します。
doctor.sh は問題が起きたときの診断、check.sh はこのリポジトリ自身の型検査・テスト・Markdown検査をまとめて実行します。

## Orca MCPは途中の開発セッションも引き継げる

普段からOMP / OpenCodeをフルアクセスで使う前提なので、既存terminalの出力も読めます。
途中まで進めた案件をChatGPTからレビューし、そのまま軌道修正や部分的な引き継ぎができます。

既存terminalへ入力するときだけ `orca_attach_terminal` を1回挟みます。
これは権限制限ではなく、別のterminalへ誤送信しないためのガードです。
attachできるのは、OrcaがOMP / OpenCode / Codexとして認識しているterminalです。
引き継ぎを解除したい場合は `orca_detach_terminal` を使い、terminal自体は残します。
既存terminalの終了はChatGPTから行わず、orca-mcp自身が起動したterminalだけ閉じられます。

- worktree一覧
- terminal一覧・状態確認
- 既存terminalを含む出力読み取り
- 既存terminalの引き継ぎ
- 既存terminalの引き継ぎ解除
- 引き継いだterminalへの入力・待機
- 新しいworktreeとOMP / OpenCode / Codexの起動
- orca-mcpが起動したterminalの終了

DevSpaceは本体を改造しません。
Secure MCP Tunnelとの接続設定だけをこのリポジトリで管理します。

Secure MCP Tunnelの表示名は `Orca MCP` と `DevSpace MCP`、内部alias/profileは
`orca-mcp` と `devspace-mcp` を使います。

## 秘密情報はGitに入れない

API keyやTunnel IDなどの実値はコミットしません。
.env.example は変数名だけを示す見本です。
実値はローカルの環境変数か、tunnel-client が対応する秘密情報の参照方法で渡します。
常駐runtimeにはTunnelsのRead + Useだけを持つRestricted keyを使い、Manage権限を持つ管理用keyは渡しません。

## 問題が起きたらstatusから確認する

まず ./scripts/status.sh、次に ./scripts/doctor.sh を実行します。
それでも原因が分からない場合は、出力をChatGPTへ渡してこのリポジトリを確認します。

最終更新: 2026-09-20
