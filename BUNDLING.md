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
  node | node.exe          # official Node runtime for <target>
  lib/
    dist/                  # compiled app (+ tree-sitter .wasm grammars, schema.sql)
    node_modules/          # production deps only (pure JS / wasm — portable)
  bin/
    codegraph | codegraph.cmd   # launcher → runs the bundled Node with the app
```

Targets: `darwin-arm64`, `darwin-x64`, `linux-x64`, `linux-arm64`, `win32-x64`,
`win32-arm64`. Unix targets produce `.tar.gz` (shell launcher); Windows produces
`.zip` (`node.exe` + a `.cmd` launcher).

```bash
scripts/build-bundle.sh linux-x64            # -> release/codegraph-linux-x64.tar.gz
scripts/build-bundle.sh win32-x64            # -> release/codegraph-win32-x64.zip
scripts/build-bundle.sh darwin-arm64         # -> release/codegraph-darwin-arm64.tar.gz
```

Because dropping better-sqlite3 left **zero native addons**, building a bundle is
pure file-packaging — **any** target builds on **any** OS (the whole matrix builds
on one Linux runner). Cross-compilation isn't a concern; only *run-testing* a
bundle needs the target platform (or emulation, e.g. `docker run --platform
linux/amd64`).

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
   real work runs on the bundled Node 24. Works even on old Node. On Windows it
   invokes the bundled `node.exe` against the app entry directly (not the `.cmd`
   launcher) — modern Node throws `EINVAL` when asked to spawn a `.cmd`/`.bat`.
3. **Windows** ([`install.ps1`](install.ps1)) — `irm … | iex`; same flow as
   install.sh (detect arch, pull the `.zip` from Releases, add to PATH).
4. **Homebrew / Scoop** — TODO (tap + cask pointing at the Release archives).

> **Personal note:** I primarily use this on `darwin-arm64` (M-series Mac) and
> `linux-x64` (VPS). The `linux-arm64` and Windows targets are untested on my end
> — use them at your own risk until I get around to verifying them. The
> `darwin-x64` target should still work fine on Intel Macs.
