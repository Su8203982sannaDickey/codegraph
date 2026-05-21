# Distribution: self-contained bundles

CodeGraph ships a **vendored Node runtime** alongside the app. Because Node 22.5+
has a built-in real SQLite (`node:sqlite`, with WAL + FTS5), bundling Node means:

- **No native build** — `better-sqlite3` is gone, so there are zero native addons
  to compile or rebuild.
- **No wasm fallback** — and therefore no more `database is locked` (issue #238).
- **No Node-version dependence** — the app always runs on the bundled Node,
  whatever the user has (or doesn't have) installed.

## What's in a bundle

Built by [`scripts/build-bundle.sh`](scripts/build-bundle.sh) — one archive per
platform, identical recipe (only the Node download differs):

```
codegraph-<target>/
  node                     # official Node runtime for <target>
  lib/
    dist/                  # compiled app (+ tree-sitter .wasm grammars, schema.sql)
    node_modules/          # production deps only (pure JS / wasm — portable)
  bin/
    codegraph              # launcher: exec "$DIR/node" "$DIR/lib/dist/bin/codegraph.js" "$@"
```

Targets: `darwin-arm64`, `darwin-x64`, `linux-x64`, `linux-arm64` (Windows: TODO).

```bash
scripts/build-bundle.sh linux-x64            # -> release/codegraph-linux-x64.tar.gz
scripts/build-bundle.sh darwin-arm64 v24.16.0
```

Note: the script does **not** cross-compile — it downloads the official Node
binary for `<target>`, but to *run-test* a bundle you must be on that platform
(or emulate it, e.g. `docker run --platform linux/amd64`).

## Install channels (all deliver the same bundle)

1. **`curl | sh`** ([`install.sh`](install.sh)) — no Node required; ideal for a
   fresh Linux VPS over SSH. Detects os/arch, pulls the archive from GitHub
   Releases, symlinks `codegraph` onto PATH. Re-run to upgrade; `--uninstall` to
   remove.
2. **npm** ([`scripts/npm-shim.js`](scripts/npm-shim.js)) — preserves
   `npm i -g @colbymchenry/codegraph`. The main package is a tiny shim; the
   bundles ship as per-platform `optionalDependencies`
   (`@colbymchenry/codegraph-<target>` with `os`/`cpu`), so npm installs only the
   matching one. The shim — run by the user's Node — execs the bundle, so the
   real work runs on the bundled Node 24. Works even on old Node.
3. **Homebrew / Scoop** — TODO (tap + cask pointing at the Release archives).

## Release pipeline (TODO)

- CI matrix (one runner per os/arch) runs `build-bundle.sh`, uploads each archive
  to the GitHub Release.
- Publish the npm main shim package + the per-platform packages.
- **Code signing** is the main gap for "download & run": macOS Gatekeeper needs a
  Developer ID + notarization; Windows needs Authenticode. Homebrew softens the
  macOS case (handles quarantine).
- Once bundles ship, retire the Node-version gate in `src/bin/codegraph.ts` — the
  bundle always runs Node 24, and the npm shim does no tree-sitter work, so no
  version check is needed.
