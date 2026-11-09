#!/usr/bin/env bash
# Install pinned Linux x86_64 tools after checking their release SHA256.
set -euo pipefail

case "${1:-}" in
  chezmoi)
    version=2.74.0
    archive="chezmoi_${version}_linux_amd64.tar.gz"
    url="https://github.com/twpayne/chezmoi/releases/download/v${version}/${archive}"
    checksum=1b98a567f726f41540414aea4caf912699d53e248b29ccf8369cf553657b2374
    member=chezmoi
    ;;
  gitleaks)
    version=8.30.1
    archive="gitleaks_${version}_linux_x64.tar.gz"
    url="https://github.com/gitleaks/gitleaks/releases/download/v${version}/${archive}"
    checksum=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
    member=gitleaks
    ;;
  uv)
    version=0.13.7
    archive=uv-x86_64-unknown-linux-gnu.tar.gz
    url="https://github.com/astral-sh/uv/releases/download/${version}/${archive}"
    checksum=c5221ff41b7892bfc223543883600125f6a47fe845093e0f5bdff4f359196d83
    member=uv-x86_64-unknown-linux-gnu/uv
    ;;
  *) echo "usage: install-ci-tool.sh {chezmoi|gitleaks|uv}" >&2; exit 2 ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 "$url" -o "$work/$archive"
printf '%s  %s\n' "$checksum" "$work/$archive" | sha256sum --check --strict
# Extract only the expected binary, after verification. No root access is needed.
tar -xzf "$work/$archive" -C "$work" "$member"
mkdir -p "$HOME/.local/bin"
install -m 0755 "$work/$member" "$HOME/.local/bin/$1"
printf '%s\n' "$HOME/.local/bin" >>"$GITHUB_PATH"
