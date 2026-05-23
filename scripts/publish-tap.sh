#!/usr/bin/env bash
#
# scripts/publish-tap.sh
# Publish the current release to the Homebrew tap repo.
#
# What it does:
#   1. Resolves the version to publish (CLI arg, or auto-detected from src/pg-sync).
#   2. Downloads the release tarball from GitHub and computes its sha256
#      (authoritative — uses what GitHub actually serves, not local builds).
#   3. Updates Formula/pg-sync.rb in THIS repo with the new url/version/sha256.
#   4. Clones (or pulls) the tap repo to a workspace dir.
#   5. Copies the updated formula and a README into the tap repo.
#   6. Commits with .gitmessage-compliant message, pushes to origin/main.
#
# Idempotent: re-running for the same version is a no-op (no commit, no push).
#
# Usage:
#   scripts/publish-tap.sh                       # auto-detect version from src/pg-sync
#   scripts/publish-tap.sh 1.0.1                 # specific version
#   scripts/publish-tap.sh --dry-run             # show what would happen, no writes
#   scripts/publish-tap.sh --tap-dir /path/to/X  # use existing clone instead of default
#

set -euo pipefail

# --- Config -----------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

PROJECT_REPO="nixrajput/pg-sync"
TAP_REPO="nixrajput/homebrew-pg-sync"
DEFAULT_TAP_DIR="$REPO_ROOT/../homebrew-pg-sync"

# --- Helpers ----------------------------------------------------------------
say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# --- Parse args -------------------------------------------------------------
VERSION=""
DRY_RUN=0
TAP_DIR="$DEFAULT_TAP_DIR"

while (( $# > 0 )); do
    case "$1" in
        --dry-run)    DRY_RUN=1 ;;
        --tap-dir)    shift; TAP_DIR="$1" ;;
        --tap-dir=*)  TAP_DIR="${1#*=}" ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*) die "Unknown flag: $1" ;;
        *)  VERSION="$1" ;;
    esac
    shift
done

# --- Resolve version --------------------------------------------------------
if [[ -z "$VERSION" ]]; then
    VERSION=$(grep -E '^readonly SCRIPT_VERSION=' "$REPO_ROOT/src/pg-sync" \
        | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$VERSION" ]] && die "Could not auto-detect version from src/pg-sync"
fi
say "Publishing pg-sync v$VERSION to tap $TAP_REPO"
(( DRY_RUN )) && warn "DRY RUN — no changes will be written or pushed"

# --- Verify required tools --------------------------------------------------
say "Checking prerequisites"
for cmd in curl shasum git; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found in PATH"
    ok "$cmd"
done

# --- Download release tarball + compute hash --------------------------------
say "Fetching GitHub release v$VERSION"
TARBALL_URL="https://github.com/${PROJECT_REPO}/releases/download/v${VERSION}/pg-sync-${VERSION}.tar.gz"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if ! curl -fsSL --retry 3 -o "$TMP/release.tar.gz" "$TARBALL_URL"; then
    die "Could not download $TARBALL_URL — is the release published?"
fi
SIZE=$(wc -c < "$TMP/release.tar.gz" | tr -d ' ')
ok "Downloaded $SIZE bytes from GitHub"

NEW_SHA=$(shasum -a 256 "$TMP/release.tar.gz" | awk '{print $1}')
[[ "${#NEW_SHA}" -eq 64 ]] || die "sha256 length is not 64 chars: $NEW_SHA"
ok "sha256: $NEW_SHA"

# --- Update source-of-truth formula in this repo ---------------------------
say "Updating Formula/pg-sync.rb in $REPO_ROOT"
FORMULA="$REPO_ROOT/Formula/pg-sync.rb"
[[ -f "$FORMULA" ]] || die "Formula not found: $FORMULA"

# Read current values to detect a no-op
CURRENT_VERSION=$(grep -E '^\s*version\s+"' "$FORMULA" | sed -E 's/.*"([^"]+)".*/\1/')
CURRENT_SHA=$(grep -E '^\s*sha256\s+"' "$FORMULA" | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$CURRENT_VERSION" == "$VERSION" && "$CURRENT_SHA" == "$NEW_SHA" ]]; then
    ok "Formula already at v$VERSION with matching sha256 — skipping rewrite"
elif (( DRY_RUN )); then
    warn "Would update url/version/sha256 in $FORMULA"
    warn "  version: $CURRENT_VERSION -> $VERSION"
    warn "  sha256:  $CURRENT_SHA -> $NEW_SHA"
else
    awk -v v="$VERSION" -v sha="$NEW_SHA" -v repo="$PROJECT_REPO" '
        /^\s*url\s+"/      { print "  url \"https://github.com/" repo "/releases/download/v" v "/pg-sync-" v ".tar.gz\""; next }
        /^\s*version\s+"/  { print "  version \"" v "\""; next }
        /^\s*sha256\s+"/   { print "  sha256 \"" sha "\""; next }
        { print }
    ' "$FORMULA" > "$FORMULA.tmp"
    mv "$FORMULA.tmp" "$FORMULA"
    ok "Updated $FORMULA"
fi

# --- Clone or update tap repo ----------------------------------------------
say "Preparing tap workspace: $TAP_DIR"
if [[ -d "$TAP_DIR/.git" ]]; then
    ok "Tap clone exists — fetching latest"
    (( DRY_RUN )) || git -C "$TAP_DIR" fetch origin >/dev/null
    (( DRY_RUN )) || git -C "$TAP_DIR" checkout main >/dev/null 2>&1 || \
        git -C "$TAP_DIR" checkout -B main >/dev/null
    (( DRY_RUN )) || git -C "$TAP_DIR" pull --ff-only origin main >/dev/null 2>&1 || \
        warn "Tap repo may be empty (first push) — that's fine"
else
    if (( DRY_RUN )); then
        warn "Would clone git@github.com:${TAP_REPO}.git into $TAP_DIR"
    else
        mkdir -p "$(dirname "$TAP_DIR")"
        if ! git clone "git@github.com:${TAP_REPO}.git" "$TAP_DIR" 2>/dev/null; then
            warn "Clone failed (empty repo?) — initializing local clone manually"
            mkdir -p "$TAP_DIR"
            git -C "$TAP_DIR" init -q -b main
            git -C "$TAP_DIR" remote add origin "git@github.com:${TAP_REPO}.git"
        else
            # Cloning an empty remote leaves us with no checked-out branch and
            # a HEAD of "master" by default; force the local branch to main so
            # subsequent commits and the push go to the right place.
            git -C "$TAP_DIR" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
        fi
        ok "Tap repo ready at $TAP_DIR"
    fi
fi

# --- Copy formula into tap repo --------------------------------------------
say "Updating tap repo contents"
if (( ! DRY_RUN )); then
    mkdir -p "$TAP_DIR/Formula"
    cp "$FORMULA" "$TAP_DIR/Formula/pg-sync.rb"
    ok "Copied formula to tap"

    # Write/refresh the tap README only if missing — don't clobber edits
    if [[ ! -f "$TAP_DIR/README.md" ]]; then
        cat > "$TAP_DIR/README.md" <<EOF
# homebrew-pg-sync

Homebrew tap for [pg-sync](https://github.com/${PROJECT_REPO}) — an interactive PostgreSQL dump / restore / sync helper for RDS-style remote databases.

## Install

\`\`\`bash
brew tap ${PROJECT_REPO}
brew install pg-sync
\`\`\`

## Update

\`\`\`bash
brew update
brew upgrade pg-sync
\`\`\`

## Uninstall

\`\`\`bash
brew uninstall pg-sync
brew untap ${PROJECT_REPO}
\`\`\`

## See also

- Source, issues, releases: <https://github.com/${PROJECT_REPO}>
- License: [MIT](https://github.com/${PROJECT_REPO}/blob/main/LICENSE)
EOF
        ok "Wrote tap README"
    fi
fi

# --- Commit and push --------------------------------------------------------
say "Committing to tap repo"

if (( DRY_RUN )); then
    warn "Would commit and push tap updates for v$VERSION"
    exit 0
fi

cd "$TAP_DIR"

git add -A
if git diff --cached --quiet; then
    ok "No changes to commit — tap is already up to date for v$VERSION"
    exit 0
fi

# Build a .gitmessage-compliant commit
if git log --oneline -1 >/dev/null 2>&1; then
    # Subsequent release — use "chore: bump …"
    COMMIT_SUBJECT="chore: bump pg-sync to v$VERSION"
    COMMIT_BODY="- Update url, version, and sha256 for v$VERSION release."
else
    # First commit — use "feat: add …"
    COMMIT_SUBJECT="feat: add pg-sync v$VERSION formula"
    COMMIT_BODY=$'- Add Homebrew formula for pg-sync v'"$VERSION"$'.
- Add tap README with install, update, and uninstall instructions.'
fi

git commit -m "$COMMIT_SUBJECT" -m "$COMMIT_BODY"
ok "Committed: $COMMIT_SUBJECT"

say "Pushing to origin/main"
git push -u origin main
ok "Pushed"

# --- Done -------------------------------------------------------------------
echo
say "Tap published successfully"
echo
echo "Verify the install end-to-end:"
echo "  brew untap ${PROJECT_REPO} 2>/dev/null || true"
echo "  brew tap ${PROJECT_REPO}"
echo "  brew install pg-sync"
echo "  pg-sync --version"
