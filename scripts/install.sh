#!/usr/bin/env bash
#
# scripts/install.sh
# One-liner installer for pg-sync. Designed to be served from
# https://raw.githubusercontent.com/nixrajput/pg-sync/main/scripts/install.sh
#
# Usage:
#   curl -fsSL https://.../install.sh | bash
#   curl -fsSL https://.../install.sh | PG_SYNC_PREFIX=/usr/local bash
#   curl -fsSL https://.../install.sh | PG_SYNC_VERSION=1.0.0 bash
#

set -euo pipefail

REPO="${PG_SYNC_REPO:-nixrajput/pg-sync}"
PREFIX="${PG_SYNC_PREFIX:-$HOME/.local}"
VERSION="${PG_SYNC_VERSION:-latest}"

# --- Helpers ---------------------------------------------------------------
say()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# --- Prerequisites ---------------------------------------------------------
say "Checking prerequisites"
for cmd in curl tar shasum; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found in PATH"
    ok "$cmd"
done

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    darwin|linux) ok "OS: $OS" ;;
    *) die "Unsupported OS: $OS (use WSL or Git Bash on Windows)" ;;
esac

# --- Resolve version -------------------------------------------------------
if [[ "$VERSION" == "latest" ]]; then
    say "Resolving latest release"
    # Use the GitHub API to find the latest tag (tag_name) without jq.
    # We grep for "tag_name": then extract the quoted value with sed.
    VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep -m1 '"tag_name":' \
        | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/')
    if [[ -z "$VERSION" ]]; then
        die "Could not resolve latest version from GitHub API. Set PG_SYNC_VERSION manually."
    fi
fi
ok "Version: $VERSION"

# --- Download tarball + checksum -------------------------------------------
TARBALL="pg-sync-${VERSION}.tar.gz"
TARBALL_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${TARBALL}"
SHA_URL="${TARBALL_URL}.sha256"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

say "Downloading $TARBALL"
curl -fsSL --retry 3 -o "$TMP/$TARBALL" "$TARBALL_URL" \
    || die "Download failed: $TARBALL_URL"
ok "Got tarball ($(wc -c < "$TMP/$TARBALL") bytes)"

say "Downloading checksum"
curl -fsSL --retry 3 -o "$TMP/$TARBALL.sha256" "$SHA_URL" \
    || die "Could not download checksum file"

say "Verifying checksum"
( cd "$TMP" && shasum -a 256 -c "$TARBALL.sha256" >/dev/null ) \
    || die "Checksum verification failed — refusing to install"
ok "Checksum verified"

# --- Extract and install ---------------------------------------------------
say "Extracting"
tar -xzf "$TMP/$TARBALL" -C "$TMP"
EXTRACTED="$TMP/pg-sync-${VERSION}"

mkdir -p "$PREFIX/bin"
install -m 0755 "$EXTRACTED/bin/pg-sync" "$PREFIX/bin/pg-sync"
ok "Installed to $PREFIX/bin/pg-sync"

# Optional: docs (top-level markdown files shipped by build.sh)
DOC_DIR="$PREFIX/share/doc/pg-sync"
docs_installed=0
for doc in README.md LICENSE CHANGELOG.md RELEASING.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md; do
    if [[ -f "$EXTRACTED/$doc" ]]; then
        mkdir -p "$DOC_DIR"
        install -m 0644 "$EXTRACTED/$doc" "$DOC_DIR/$doc"
        docs_installed=1
    fi
done
(( docs_installed )) && ok "Installed docs to $DOC_DIR"

# --- PATH hint -------------------------------------------------------------
say "Verifying PATH"
case ":$PATH:" in
    *":$PREFIX/bin:"*)
        ok "$PREFIX/bin is already on PATH"
        ;;
    *)
        warn "$PREFIX/bin is NOT on your PATH."
        SHELL_NAME=$(basename "${SHELL:-/bin/bash}")
        case "$SHELL_NAME" in
            zsh)  RC="$HOME/.zshrc" ;;
            bash) RC="$HOME/.bashrc" ;;
            fish) RC="$HOME/.config/fish/config.fish" ;;
            *)    RC="$HOME/.profile" ;;
        esac
        echo
        echo "  Add this line to $RC:"
        if [[ "$SHELL_NAME" == "fish" ]]; then
            echo "      set -gx PATH \"$PREFIX/bin\" \$PATH"
        else
            echo "      export PATH=\"$PREFIX/bin:\$PATH\""
        fi
        echo "  Then reload: source $RC"
        ;;
esac

# --- Done ------------------------------------------------------------------
echo
say "pg-sync $VERSION installed"
"$PREFIX/bin/pg-sync" --version 2>/dev/null || true
echo
echo "  Run: pg-sync --help"
