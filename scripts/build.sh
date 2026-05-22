#!/usr/bin/env bash
#
# scripts/build.sh
# Build release artifacts for pg-sync.
#
# Produces:
#   dist/pg-sync-<version>.tar.gz          (portable bash source)
#   dist/pg-sync-<version>.tar.gz.sha256
#   dist/pg-sync-<version>-<platform>      (optional shc-compiled binary, if shc is installed)
#   dist/pg-sync-<version>-<platform>.sha256
#
# Usage:
#   scripts/build.sh                 # full build
#   scripts/build.sh --no-binary     # skip shc binary even if shc is installed
#

set -euo pipefail

# --- Locate repo root -------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

# --- Flags ------------------------------------------------------------------
BUILD_BINARY=1
for arg in "$@"; do
    case "$arg" in
        --no-binary) BUILD_BINARY=0 ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# --- Determine version from src/pg-sync -------------------------------------
VERSION=$(grep -E '^readonly SCRIPT_VERSION=' src/pg-sync \
    | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$VERSION" ]]; then
    echo "Could not extract SCRIPT_VERSION from src/pg-sync" >&2
    exit 1
fi
echo "==> Building pg-sync v$VERSION"

# --- Platform detection -----------------------------------------------------
OS=$(uname -s | tr '[:upper:]' '[:lower:]')   # darwin / linux
ARCH=$(uname -m)                              # x86_64 / arm64 / aarch64
case "$ARCH" in
    x86_64|amd64)  ARCH=x86_64 ;;
    arm64|aarch64) ARCH=arm64 ;;
esac
PLATFORM="${OS}-${ARCH}"
echo "    Platform: $PLATFORM"

# --- Clean and recreate dist/ + bin/ ----------------------------------------
rm -rf dist bin
mkdir -p dist bin

# --- Stage the launcher into bin/ ------------------------------------------
# bin/pg-sync is the released entrypoint. Currently it's a straight copy of
# src/pg-sync — if you ever split src/ into multiple files, this is where
# you'd concatenate them into a single launcher.
cp src/pg-sync bin/pg-sync
chmod +x bin/pg-sync
echo "==> Staged bin/pg-sync"

# --- Sanity: syntax check ---------------------------------------------------
bash -n bin/pg-sync
echo "    bash -n: OK"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning bin/pg-sync || {
        echo "shellcheck found issues — aborting build" >&2
        exit 1
    }
    echo "    shellcheck: OK"
else
    echo "    shellcheck not installed — skipping static analysis"
fi

# --- Portable tarball -------------------------------------------------------
STAGE_DIR="dist/pg-sync-${VERSION}"
mkdir -p "$STAGE_DIR/bin"
cp bin/pg-sync "$STAGE_DIR/bin/"
cp README.md LICENSE CHANGELOG.md "$STAGE_DIR/"
# Ship maintainer + contributor docs alongside the binary when present.
for doc in RELEASING.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md; do
    [[ -f "$doc" ]] && cp "$doc" "$STAGE_DIR/"
done

tar -czf "dist/pg-sync-${VERSION}.tar.gz" -C dist "pg-sync-${VERSION}"
rm -rf "$STAGE_DIR"
echo "==> Wrote dist/pg-sync-${VERSION}.tar.gz"

# --- Checksum ---------------------------------------------------------------
( cd dist && shasum -a 256 "pg-sync-${VERSION}.tar.gz" > "pg-sync-${VERSION}.tar.gz.sha256" )
echo "==> Wrote dist/pg-sync-${VERSION}.tar.gz.sha256"

# --- Optional shc binary ---------------------------------------------------
# shc compiles bash to a (very thin) C wrapper that calls bash internally.
# It produces a per-platform binary. We build it only if shc is installed.
if (( BUILD_BINARY )) && command -v shc >/dev/null 2>&1; then
    echo "==> Compiling standalone binary with shc"
    BIN_OUT="dist/pg-sync-${VERSION}-${PLATFORM}"
    # shc writes alongside the input file with .x extension; we control via -o
    shc -r -f bin/pg-sync -o "$BIN_OUT"
    rm -f bin/pg-sync.x.c
    chmod +x "$BIN_OUT"
    ( cd dist && shasum -a 256 "$(basename "$BIN_OUT")" > "$(basename "$BIN_OUT").sha256" )
    echo "    Wrote $BIN_OUT (+ .sha256)"
    echo "    Note: binary still requires Bash + PostgreSQL clients at runtime."
    case "$OS" in
        darwin)
            echo "    macOS: to distribute outside your machine, you must codesign + notarize."
            echo "    Otherwise users will see a Gatekeeper warning on first run."
            ;;
    esac
else
    if (( BUILD_BINARY )); then
        echo "    shc not found — skipping binary build (install with 'brew install shc')"
    else
        echo "    --no-binary requested — skipping binary build"
    fi
fi

# --- Summary ---------------------------------------------------------------
echo
echo "==> Build complete"
echo
ls -lh dist/ | sed 's/^/    /'
echo
echo "Next steps:"
echo "  • Test locally:   tar -tzf dist/pg-sync-${VERSION}.tar.gz | head"
echo "  • Verify install: tar -xzf dist/pg-sync-${VERSION}.tar.gz -C /tmp && /tmp/pg-sync-${VERSION}/bin/pg-sync --version"
echo "  • Tag and push:   git tag -a v${VERSION} -m \"v${VERSION}\" && git push origin v${VERSION}"
