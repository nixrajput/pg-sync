# Security Policy

We take the security of `pg-sync` seriously. This document explains how to report issues and what to expect in return.

## Supported versions

`pg-sync` is in its initial release. Security fixes target the latest released version only:

| Version | Supported |
| ------- | --------- |
| 1.0.x   | ✅ Latest |

Once we have multiple minor releases, this policy will widen to **the two most recent minor lines** — for example, when `1.2.0` ships, both `1.2.x` and `1.1.x` will receive fixes; `1.0.x` will be unsupported.

If you are on an older release than the latest, please upgrade first — the issue may already be fixed.

## Reporting a vulnerability

**Please do not open a public GitHub issue.** Use one of these private channels instead:

1. **GitHub Security Advisories** (preferred): <https://github.com/nixrajput/pg-sync/security/advisories/new>
2. **Email:** `security@<your-domain>` (replace with a real address before publishing the repo)

Include in your report:

- A clear description of the issue and its impact
- Step-by-step reproduction with the exact commands used
- `pg-sync --version` output
- OS, shell, and PostgreSQL client versions
- Any relevant logs (please redact credentials before sharing)

## What to expect

- **Acknowledgement** within **72 hours** of receipt.
- **An assessment** with a severity rating (CVSS-style) within **7 days**.
- **A fix or mitigation timeline** communicated within **14 days**.
- **Credit** in the release notes if you'd like (or anonymous if you prefer).

We follow **coordinated disclosure**: we'll work with you on a fix, publish a patched release, then publish the advisory. We aim to never sit on reports — if a fix is delayed, you'll know why.

## Out of scope

The following are NOT considered vulnerabilities in `pg-sync`:

- Bugs in PostgreSQL itself or its client tools (`pg_dump`, `pg_restore`, `psql`). Report those upstream.
- Misconfigurations of the user's local Postgres (e.g. `fsync=off` left on after a restore) — we already warn about these.
- Issues that require the attacker to already control the user's machine.
- Plain-text passwords in command-line arguments to third-party tools that `pg-sync` invokes (this is a `pg_dump` / `psql` design, not ours).

## What we do to protect users

- Passwords are read with `read -s` (no terminal echo, no shell history).
- `PGPASSWORD` is set per-command via env vars, never written to disk.
- All SQL interpolation of user input goes through a `sql_escape` helper.
- Checksums are published with every release and verified by the installer.
- `set -euo pipefail` is on at script-level to fail fast on unexpected errors.

Thanks for helping keep `pg-sync` and its users safe.
