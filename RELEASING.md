# Releasing pg-sync

> End-to-end runbook for cutting a new release.
> Audience: maintainers with push access to the repo and the Homebrew tap.

This document covers the **what**, **why**, and **how** of every step. Read it top-to-bottom the first time. After that, the [TL;DR checklist](#tldr-checklist) at the bottom is enough.

---

## Versioning policy

We follow [Semantic Versioning](https://semver.org/):

| Bump  | When                                                                      | Example         |
| ----- | ------------------------------------------------------------------------- | --------------- |
| MAJOR | Incompatible CLI/UX changes (renamed flags, removed modes, schema breaks) | `1.0.0 → 2.0.0` |
| MINOR | Backwards-compatible new functionality                                    | `1.0.0 → 1.1.0` |
| PATCH | Backwards-compatible bug fixes                                            | `1.0.0 → 1.0.1` |

Pre-releases use `-rc.N` suffix (e.g. `1.1.0-rc.1`). They follow the same tagging process but are marked as **pre-release** on GitHub so install scripts and Homebrew don't auto-pick them up.

---

## Prerequisites

You need:

- **Push access** to `nixrajput/pg-sync` (this repo).
- **Push access** to `nixrajput/homebrew-pg-sync` (the Homebrew tap repo).
- **A clean working tree** on `main`: `git status` should show nothing dirty.
- **shellcheck** locally for `make lint`: `brew install shellcheck`.
- **A GitHub token** in your shell for `gh` CLI (recommended): `gh auth login`.

If you don't have `gh`, you can do the release manually via the web UI — the runbook calls out both paths.

---

## High-level flow

```
[1] Bump version  →  [2] Update CHANGELOG  →  [3] Lint + test
                                                     ↓
[6] Update Homebrew  ←  [5] CI builds + releases  ←  [4] Tag + push
                                ↑
                       (automated)
```

Steps 1–4 are manual. Step 5 is automated by GitHub Actions. Step 6 is one command (`make publish-tap`) which wraps `scripts/publish-tap.sh`.

---

## Step 1 — Bump the version

The script's version lives in **one place**: `src/pg-sync`, line ~36, in the constant `SCRIPT_VERSION`.

```bash
# Find it and edit:
grep -n SCRIPT_VERSION src/pg-sync
```

Update it to the new version (without the leading `v`):

```bash
readonly SCRIPT_VERSION="1.1.0"
```

The `Makefile`, `scripts/build.sh`, and CI all extract the version from this single line via `sed`. Do **not** hard-code the version anywhere else.

> **Why a single source of truth?** When CI builds the tarball, it names the
> file `pg-sync-${VERSION}.tar.gz`. Any drift between what the script reports
> and what the tarball is named will confuse users.

---

## Step 2 — Update the CHANGELOG

Open `CHANGELOG.md` and:

1. **Move the `[Unreleased]` heading** down — convert the previous `## [Unreleased]` into `## [1.1.0] - YYYY-MM-DD`.
2. **Add a fresh empty `## [Unreleased]`** above it so the next contributor has a place to add notes.
3. **Update the link refs** at the bottom of the file:

   ```markdown
   [Unreleased]: https://github.com/nixrajput/pg-sync/compare/v1.1.0...HEAD
   [1.1.0]: https://github.com/nixrajput/pg-sync/releases/tag/v1.1.0
   [1.0.0]: https://github.com/nixrajput/pg-sync/releases/tag/v1.0.0
   ```

We follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.

Write user-facing notes, not commit messages. "Fixed crash when DB has no tables" is good; "fix bug in choose_per_table_restore" is not.

---

## Step 3 — Lint and test locally

Before tagging:

```bash
make lint    # bash -n + shellcheck
make test    # smoke tests under tests/
make build   # produce dist/ artifacts and verify them
```

All three must pass.

Then **smoke-test the built tarball** the same way an end user would:

```bash
rm -rf /tmp/pgsync_release_test
mkdir -p /tmp/pgsync_release_test
tar -xzf dist/pg-sync-*.tar.gz -C /tmp/pgsync_release_test
/tmp/pgsync_release_test/pg-sync-*/bin/pg-sync --version
/tmp/pgsync_release_test/pg-sync-*/bin/pg-sync --help | head -5
```

If `--version` reports the wrong number, you forgot Step 1.

---

## Step 4 — Tag and push

Use the `release-check` target to confirm everything is wired up:

```bash
make release-check
```

This verifies that the working tree is clean and CHANGELOG.md has an entry for the current version. If it errors out, fix what it tells you.

Then:

```bash
# Commit version bump + CHANGELOG
git add src/pg-sync CHANGELOG.md
git commit -m "Release v1.1.0"
git push origin main

# Create an annotated tag
git tag -a v1.1.0 -m "v1.1.0"

# Push the tag — this triggers CI
git push origin v1.1.0
```

> **Why annotated tags (`-a`)?** They're full Git objects with author, date,
> and message. Lightweight tags are pointers. GitHub Releases prefer annotated.

---

## Step 5 — What CI does (automated)

The moment your tag hits `origin`, `.github/workflows/release.yml` fires. Watch progress at:

```
https://github.com/nixrajput/pg-sync/actions
```

The workflow does:

1. **Build matrix** — runs on both `ubuntu-latest` and `macos-latest` to prove portability. Installs `shellcheck` and runs `make lint`.
2. **Build artifacts** — runs `bash scripts/build.sh --no-binary` on each matrix runner, producing `dist/pg-sync-${VERSION}.tar.gz` and its `.sha256` checksum.
3. **Upload artifacts** — each matrix job uploads its `dist/` to GitHub's artifact storage.
4. **Release job** — downloads all matrix artifacts, deduplicates (the tarball content is platform-agnostic, so one copy is enough), and creates the GitHub Release via `softprops/action-gh-release`.
5. **Release notes** — auto-generated from PR titles since the last tag. You can edit them after the release is created.

**Time budget:** Typically 2–4 minutes end-to-end. If it's still running after 10 minutes, something is wrong — check the logs.

### What CI does _not_ do

- **Does not update the Homebrew formula.** That's Step 6.
- **Does not produce `shc`-compiled binaries.** `--no-binary` is hardcoded because cross-compiling bash→C→binary across macOS Intel/ARM and Linux x86_64/ARM64 would need notarization (macOS) and per-arch runners.
- **Does not auto-publish to npm / Snap / etc.** Those would each need their own jobs.

---

## Step 6 — Update the Homebrew tap

After the GitHub Release exists, users on Homebrew won't see the new version until you update the tap formula.

### 6a. Run the automation (recommended)

```bash
make publish-tap
```

That single command:

1. Downloads the released tarball from GitHub.
2. Computes its sha256 (authoritative — uses what GitHub serves).
3. Updates `Formula/pg-sync.rb` in this repo with new url/version/sha256.
4. Clones or pulls the tap repo (`nixrajput/homebrew-pg-sync`) into a sibling directory.
5. Copies the updated formula into the tap repo.
6. Commits with a `.gitmessage`-compliant message and pushes to `origin/main`.

The script is **idempotent**: re-running for the same version is a no-op.

If you want to preview without writing anything:

```bash
bash scripts/publish-tap.sh --dry-run
```

### 6b. Manual fallback

If the automation fails or you prefer to do it by hand, the steps are:

1. Compute the sha256 from the release asset:

   ```bash
   curl -fsSL https://github.com/nixrajput/pg-sync/releases/download/v1.1.0/pg-sync-1.1.0.tar.gz \
       | shasum -a 256
   ```

2. Update `Formula/pg-sync.rb` in this repo — change `url`, `version`, and `sha256`.

3. Copy to the tap repo and push:

   ```bash
   cd /path/to/homebrew-pg-sync
   cp /path/to/pg-sync/Formula/pg-sync.rb Formula/pg-sync.rb
   git add Formula/pg-sync.rb
   git commit -m "chore: bump pg-sync to v1.1.0"
   git push origin main
   ```

### 6c. Smoke-test the install

```bash
brew untap nixrajput/pg-sync 2>/dev/null || true
brew tap nixrajput/pg-sync
brew install pg-sync
pg-sync --version
```

If `--version` reports `1.1.0`, you're done.

---

## Step 7 — Announce the release

Optional but recommended:

- Edit the GitHub release notes to add a short summary at the top.
- Cross-post highlights to your project's Discussions or wherever your users hang out.

---

## Rollback

If something is broken after release:

### Soft rollback (recommended)

Cut a patch release `1.1.1` that fixes the regression. Don't delete `1.1.0` — users who already installed it would get confused.

### Hard rollback (rare, last resort)

You can delete the GitHub release and force-delete the tag, but anyone who already installed it stays on the bad version. Only do this within minutes of pushing, and only if the release is genuinely unusable (e.g. installer deletes user data).

```bash
gh release delete v1.1.0 --yes
git push --delete origin v1.1.0
git tag -d v1.1.0
```

Then communicate the rollback via release notes on the next tag.

---

## TL;DR checklist

For an experienced maintainer cutting a routine release:

```bash
# 1. Bump
$EDITOR src/pg-sync                # update SCRIPT_VERSION
$EDITOR CHANGELOG.md               # move [Unreleased] to [X.Y.Z]

# 2. Verify
make lint test build
make release-check

# 3. Tag + push
git add src/pg-sync CHANGELOG.md
git commit -m "Release vX.Y.Z"
git push origin main
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z

# 4. Wait for CI: https://github.com/nixrajput/pg-sync/actions
# 5. Publish to Homebrew tap
make publish-tap

# 6. Smoke-test the install
brew untap nixrajput/pg-sync 2>/dev/null || true
brew tap nixrajput/pg-sync
brew install pg-sync
pg-sync --version
```

---

## Troubleshooting

**CI fails on `make lint`.** Run `make lint` locally — your push must not have included whatever fix you thought you had. Push the fix, then re-tag (delete the old tag first: `git push --delete origin vX.Y.Z; git tag -d vX.Y.Z`).

**`make release-check` says "CHANGELOG has no entry."** You bumped `SCRIPT_VERSION` but didn't move `[Unreleased]` to the new version heading.

**CI succeeds but the GitHub Release isn't created.** Check the _release_ job (the second one in the workflow). Token permission issues are the most common cause — confirm `permissions: contents: write` is in the workflow.

**`brew install pg-sync` installs the old version.** Did you push to the tap repo? Did you `brew update` first? `brew tap-info nixrajput/pg-sync` will show you what Homebrew thinks the latest is.

**Tarball checksum mismatch on Homebrew install.** You updated the formula but forgot to re-run `shasum -a 256` after a last-minute edit to the release asset. Recompute and push again.
