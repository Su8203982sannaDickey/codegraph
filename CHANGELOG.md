# Changelog

All notable changes to CodeGraph are documented here. Each entry also ships as
a [GitHub Release](https://github.com/colbymchenry/codegraph/releases) tagged
`vX.Y.Z`, which is where most people will look.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.4] - 2026-05-22

### Fixed
- **Orphaned `codegraph serve --mcp` processes after a parent SIGKILL.** When
  the MCP host (Claude Code, opencode, …) was force-killed — OOM killer, a
  `kill -9`, a container teardown — the child kept running indefinitely on
  Linux, holding inotify watches, file descriptors, and the SQLite WAL. The
  kernel doesn't propagate parent death to children, and the stdin
  `end`/`close` handlers we relied on don't always fire. The MCP server now
  polls `process.ppid` and shuts down the moment it changes from the value
  observed at startup; the poll interval is `CODEGRAPH_PPID_POLL_MS` (default
  `5000`, `0` disables). Resolves
  [#277](https://github.com/colbymchenry/codegraph/issues/277).

### Added
- **Release archives now ship with a `SHA256SUMS` file**, and the npm launcher
  verifies the bundle it downloads against it — a mismatch aborts before
  anything runs. Releases published before this change have no checksum file, so
  the verification is skipped (not failed) when none is available.

### Fixed
- **`codegraph: no prebuilt bundle for <platform>` after installing through a
  registry mirror.** Installing `@colbymchenry/codegraph` from a registry that
  hadn't mirrored the matching per-platform package — most often the
  npmmirror/cnpm mirrors, but any lazily-syncing mirror or corporate proxy can
  do it — left every command failing with `no prebuilt bundle for <platform>`.
  The runtime ships as a per-platform `optionalDependency`, and npm treats an
  optional package it can't fetch as a success and silently skips it, so the
  bundle simply went missing. The launcher now self-heals: when the platform
  bundle isn't installed, it downloads the same archive from GitHub Releases
  (cached under `~/.codegraph/bundles/` for next time) and runs that — so a
  global install works even on a mirror that never carried the platform package.
  Set `CODEGRAPH_NO_DOWNLOAD=1` to disable the network fallback, or
  `CODEGRAPH_DOWNLOAD_BASE=<url>` to point it at your own mirror of the release
  archives; the standalone `install.sh` remains the no-Node alternative. Resolves
  [#303](https://github.com/colbymchenry/codegraph/issues/303).
- **`install.sh` failing with `403` / "could not resolve latest version" on
  shared or cloud hosts.** The standalone installer resolved the latest release
  through the GitHub API, whose unauthenticated limit is 60 requests/hour per IP
  — routinely exhausted on cloud devboxes and CI where many users share an
  address, returning `403` (issue #325). It now resolves the version from the
  `releases/latest` web redirect, which has no rate limit. Also worth noting:
  you can pin a specific version by setting `CODEGRAPH_VERSION=0.9.4` before
  running the script — handy if you need a reproducible install in CI.
