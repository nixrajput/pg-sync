# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-05-23

Initial public release.

### Added

- Three top-level modes: full sync, dump-only, restore-only.
- Interactive main menu with Help, Version, and Quit options.
- Table-subset selection: numbered picker (with ranges like `1,3,5-8`) or free-form wildcard input (`users, orders, audit_*`).
- Exclusion list with `pg_dump`-style wildcards (e.g. `*.solid_queue_*`), applied on top of the include list.
- Pre-dump and post-restore per-table statistics: size + estimated row count, paginated for large schemas.
- Restore-only mode with auto-discovery of dumps in `~/pg_dumps/`, custom path input, and per-table restore (schema+data or data-only).
- Live heartbeat during `pg_dump`: throughput in KB/s, elapsed time, worker count, and currently-dumping table names.
- Connection URL parsing: paste `postgres://user:pass@host:5432/dbname` instead of entering five fields one by one.
- Detection of dangerous `postgresql.conf` settings (e.g. `fsync=off`) after restore, with revert guidance.
- Retry and back navigation on invalid input throughout interactive prompts — no more abrupt exits.
- CLI flags: `-h/--help`, `-V/--version`, `--dry-run`.
- `PG_SYNC_DUMP_DIR` environment variable to override the dump base directory.
- Cross-platform support: macOS (Intel + Apple Silicon), Linux (x86_64 + ARM64), Windows via WSL or Git Bash.
- Build system producing portable tarballs with sha256 checksums and an optional `shc`-compiled binary.
- Three install channels: Homebrew tap, `curl | bash` one-liner, and tarball download.
- GitHub Actions workflow that builds and publishes releases on tag push.
- Project documentation: README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, RELEASING runbook, plus issue/PR templates.

[Unreleased]: https://github.com/nixrajput/pg-sync/compare/v1.0.0...HEAD [1.0.0]: https://github.com/nixrajput/pg-sync/releases/tag/v1.0.0
