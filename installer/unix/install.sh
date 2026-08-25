#!/usr/bin/env bash
# Install dew-gallery to PREFIX (default /usr/local)
set -euo pipefail
PREFIX="${PREFIX:-/usr/local}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$ROOT/examples/gallery/dew-gallery"
if [[ ! -x "$BIN" ]]; then
  echo "Build first: (cd examples/gallery && dub build --build=release)" >&2
  exit 1
fi
install -d "$PREFIX/bin"
install -m 755 "$BIN" "$PREFIX/bin/dew-gallery"
echo "Installed $PREFIX/bin/dew-gallery"
