#!/usr/bin/env bash
# Linux / WSL 用。公式 Release の実在するアセットを選択し、SHA-256 を確認。
# 実行: bash scripts/install-lazygit.sh
# 版固定: LAZYGIT_VERSION=v0.64.1 bash scripts/install-lazygit.sh
# インストール先: ~/.local/bin（sudo 不要）。シェル設定は変更しない。
set -euo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
for cmd in curl jq tar sha256sum uname mktemp install awk; do
  command -v "$cmd" >/dev/null 2>&1 || fail "必要なコマンドがありません: $cmd"
done
[[ "$(uname -s)" == Linux ]] || fail 'Linux / WSL 内で実行してください。'
case "$(uname -m)" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) fail "未対応の CPU: $(uname -m)" ;;
esac

version="${LAZYGIT_VERSION:-latest}"
api='https://api.github.com/repos/jesseduffield/lazygit/releases'
if [[ "$version" == latest ]]; then
  api="$api/latest"
else
  version="${version#v}"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail '版は v0.64.1 のように指定してください。'
  api="$api/tags/v$version"
fi

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
fetch() {
  curl --fail --silent --show-error --location --retry 3 \
    --connect-timeout 15 --max-time 180 \
    --proto '=https' --proto-redir '=https' "$1" -o "$2"
}
fetch "$api" "$tmp/release.json"
tag="$(jq -er '.tag_name | select(type == "string" and length > 0)' "$tmp/release.json")"

# Linux / linux の表記差を吸収し、URL やファイル名を決め打ちしない。
asset="$(jq -cer --arg arch "$arch" '
  [.assets[] | select(.name | test("^lazygit_.*_linux_" + $arch + "\\.tar\\.gz$"; "i"))]
  | if length == 1 then .[0] else error("対応するアセットが一意に見つかりません") end
' "$tmp/release.json")"
archive="$(jq -er '.name' <<<"$asset")"
url="$(jq -er '.browser_download_url' <<<"$asset")"
checksum_url="$(jq -er '
  [.assets[] | select(.name == "checksums.txt")]
  | if length == 1 then .[0].browser_download_url else error("checksums.txt がありません") end
' "$tmp/release.json")"

printf 'Downloading lazygit %s (%s)\n' "$tag" "$arch"
fetch "$url" "$tmp/$archive"
fetch "$checksum_url" "$tmp/checksums.txt"
awk -v name="$archive" '
  $2 == name || $2 == "*" name {print; count++}
  END {if (count != 1) exit 1}
' "$tmp/checksums.txt" > "$tmp/selected-checksum.txt"
(cd "$tmp" && sha256sum -c selected-checksum.txt)
tar --extract --gzip --file="$tmp/$archive" --directory="$tmp" --no-same-owner lazygit
[[ -f "$tmp/lazygit" && ! -L "$tmp/lazygit" ]] || fail '展開した実行ファイルが不正です。'

mkdir -p "$HOME/.local/bin"
# GNU install の番号付きバックアップで、既存のローカル版を保護する。
install --backup=numbered -m 0755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
"$HOME/.local/bin/lazygit" --version
printf 'Installed: %s/.local/bin/lazygit\n' "$HOME"
printf 'PATH の先頭に ~/.local/bin を追加し、zsh では rehash を実行してください。\n'
