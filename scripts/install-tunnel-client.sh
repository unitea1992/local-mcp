#!/usr/bin/env bash
set -euo pipefail

for command_name in curl unzip sha256sum awk; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "必要なコマンドが見つかりません: $command_name"
    exit 1
  fi
done

case "$(uname -s)" in
  Linux) os="linux" ;;
  *)
    echo "このスクリプトは現在Linux専用です。OpenAI公式のダウンロード手順を使ってください。"
    exit 2
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch="amd64" ;;
  aarch64|arm64) arch="arm64" ;;
  *)
    echo "未対応のCPUアーキテクチャです: $(uname -m)"
    exit 2
    ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version_file="$repo_root/config/tunnel-client.version"
version="$(tr -d '[:space:]' < "$version_file")"
if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "不正なバージョン指定です: $version"
  exit 1
fi

asset="tunnel-client-${version}-${os}-${arch}.zip"
base="https://github.com/openai/tunnel-client/releases/download/${version}"

echo "検証済みのOpenAI tunnel-client ${version} を取得します"
curl -fsSL "${base}/${asset}" -o "$tmp_dir/$asset"
curl -fsSL "${base}/SHA256SUMS.txt" -o "$tmp_dir/SHA256SUMS.txt"

expected="$(awk -v name="$asset" '$2 == name {print $1}' "$tmp_dir/SHA256SUMS.txt")"
actual="$(sha256sum "$tmp_dir/$asset" | awk '{print $1}')"
if [[ -z "$expected" || "$expected" != "$actual" ]]; then
  echo "SHA256の検証に失敗しました。インストールしません。"
  exit 1
fi

install_dir="$HOME/.local/lib/tunnel-client/${version#v}"
mkdir -p "$install_dir" "$HOME/.local/bin"
unzip -p "$tmp_dir/$asset" tunnel-client > "$install_dir/tunnel-client"
chmod 0755 "$install_dir/tunnel-client"
ln -sfn "$install_dir/tunnel-client" "$HOME/.local/bin/tunnel-client"

echo "インストール完了: $($HOME/.local/bin/tunnel-client --version)"
echo "Cloudflare companionは今回使わないためインストールしていません。"

