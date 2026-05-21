#!/usr/bin/env bash
#
# Build a self-contained CodeGraph bundle: an official Node runtime + the
# compiled app + its production deps, so CodeGraph runs with NO system Node and
# NO native build — node:sqlite is built into the bundled Node. One archive per
# platform; the recipe is identical across platforms (only the Node download
# differs), so a CI matrix produces all of them.
#
# Usage:
#   scripts/build-bundle.sh <target> [node-version]
#     target:        darwin-arm64 | darwin-x64 | linux-x64 | linux-arm64
#     node-version:  e.g. v24.16.0 (default below; pin for reproducible builds)
#
# Output: release/codegraph-<target>.tar.gz  (extracts to codegraph-<target>/)
#
# NOTE: does not cross-compile — the bundled Node binary is the official build
# for <target>, but to *run-test* a bundle you must be on that platform.
set -euo pipefail

TARGET="${1:?usage: build-bundle.sh <target> [node-version]}"
NODE_VERSION="${2:-v24.16.0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/release"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

NODE_DIST="node-${NODE_VERSION}-${TARGET}"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_DIST}.tar.gz"

echo "[bundle] target=${TARGET} node=${NODE_VERSION}"

# 1. Download + extract the official Node runtime for the target platform.
echo "[bundle] downloading ${NODE_URL}"
curl -fsSL "$NODE_URL" -o "$WORK/node.tar.gz"
tar -xzf "$WORK/node.tar.gz" -C "$WORK"
NODE_BIN="$WORK/${NODE_DIST}/bin/node"
[ -f "$NODE_BIN" ] || { echo "[bundle] error: node binary not found in tarball" >&2; exit 1; }

# 2. Build the app (compiled JS + copied wasm/schema assets).
echo "[bundle] building app"
( cd "$ROOT" && npm run build >/dev/null )

# 3. Stage: vendored node + app + production-only deps + launcher.
STAGE="$WORK/codegraph-${TARGET}"
mkdir -p "$STAGE/lib" "$STAGE/bin"
cp "$NODE_BIN" "$STAGE/node"
cp -R "$ROOT/dist" "$STAGE/lib/dist"
cp "$ROOT/package.json" "$ROOT/package-lock.json" "$STAGE/lib/"
echo "[bundle] installing production dependencies"
( cd "$STAGE/lib" && npm ci --omit=dev --ignore-scripts >/dev/null 2>&1 )
rm -f "$STAGE/lib/package-lock.json"

# 4. Launcher: exec the vendored Node with the app entry. `exec` replaces the
#    shell so there's a single process, and the absolute path means the bundled
#    Node is used regardless of what's (or isn't) on the user's PATH.
cat > "$STAGE/bin/codegraph" <<'LAUNCH'
#!/bin/sh
DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$DIR/node" "$DIR/lib/dist/bin/codegraph.js" "$@"
LAUNCH
chmod +x "$STAGE/bin/codegraph"

# 5. Archive.
mkdir -p "$OUT"
ARCHIVE="$OUT/codegraph-${TARGET}.tar.gz"
# --no-xattrs: don't embed macOS extended attributes (com.apple.provenance),
# which make GNU tar warn noisily when the archive is extracted on Linux.
tar --no-xattrs -czf "$ARCHIVE" -C "$WORK" "codegraph-${TARGET}"
echo "[bundle] wrote ${ARCHIVE} ($(du -h "$ARCHIVE" | cut -f1))"
