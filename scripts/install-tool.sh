#!/usr/bin/env bash
# Install a pinned siros-wrpac-tool release and prove it is the one we expect.
#
#   install-tool.sh <version> <sha256-amd64> <sha256-arm64> [dest-dir]
#
# The digest pinned by the caller is the hard check: a release asset that does
# not match it is refused whatever its provenance says. The SLSA attestation is
# verified as well when the local gh is new enough (>= 2.49), and otherwise
# reported as skipped so the gap is visible in the log.
set -euo pipefail

VERSION="$1"; SHA_AMD64="$2"; SHA_ARM64="$3"; DEST="${4:-$HOME/.local/bin}"
REPO="sirosfoundation/siros-wrpac-tool"

case "$(uname -m)" in
  x86_64)  ARCH=amd64; WANT="$SHA_AMD64" ;;
  aarch64) ARCH=arm64; WANT="$SHA_ARM64" ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
ASSET="siros-wrpac-tool-linux-${ARCH}"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 -o "$tmp/$ASSET" \
  "https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

GOT="$(sha256sum "$tmp/$ASSET" | cut -d' ' -f1)"
if [[ "$GOT" != "$WANT" ]]; then
  echo "digest mismatch for ${ASSET} ${VERSION}: got ${GOT}, pinned ${WANT}" >&2
  exit 1
fi

if gh attestation verify --help >/dev/null 2>&1; then
  gh attestation verify "$tmp/$ASSET" --repo "$REPO"
else
  echo "::warning::gh $(gh --version | head -1) cannot verify attestations; digest check only"
fi

mkdir -p "$DEST"
install -m 0755 "$tmp/$ASSET" "$DEST/siros-wrpac-tool"
echo "$DEST" >> "${GITHUB_PATH:-/dev/null}"
"$DEST/siros-wrpac-tool" version
