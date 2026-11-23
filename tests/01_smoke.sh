#!/usr/bin/env bash
#
# tests/01_smoke.sh
# Cheap smoke tests that don't require a live PostgreSQL.
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$SCRIPT_DIR/../src/pg-sync"

PASS=0
FAIL=0
check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf '  \033[32m✓\033[0m %s\n' "$name"
        PASS=$((PASS + 1))
    else
        printf '  \033[31m✗\033[0m %s\n' "$name"
        printf '       expected: %q\n' "$expected"
        printf '       actual:   %q\n' "$actual"
        FAIL=$((FAIL + 1))
    fi
}

echo "==> bash -n"
bash -n "$SCRIPT"
echo "    OK"

echo "==> --version exits 0"
"$SCRIPT" --version >/dev/null
echo "    OK"

echo "==> --help exits 0 and mentions OPTIONS"
out=$("$SCRIPT" --help)
[[ "$out" == *"OPTIONS"* ]] && echo "    OK" || { echo "    FAIL: --help output missing OPTIONS"; exit 1; }

echo "==> Unknown flag exits 2"
rc=0
"$SCRIPT" --no-such-flag >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 2 ]] && echo "    OK (exit $rc)" || { echo "    FAIL: expected exit 2, got $rc"; exit 1; }

echo "==> Source helpers individually"
TMP=$(mktemp)
sed 's|^main "\$@"$|true|' "$SCRIPT" > "$TMP"
sed -i.bak '/^trap/d' "$TMP"
# shellcheck disable=SC1090
source "$TMP" 2>/dev/null

check "url_decode encoded @" "p@ss"     "$(url_decode 'p%40ss')"
check "url_decode + to space" "a b"     "$(url_decode 'a+b')"
check "glob_to_like star"     "%.users" "$(glob_to_like '*.users')"
check "glob_to_ere star"      ".*.users" "$(glob_to_ere '*.users')"
check "sql_escape quote"      "a''b"    "$(sql_escape "a'b")"
check "humanize bytes (B)"    "500 B"   "$(humanize_bytes 500)"
check "sql_ident quote"       '"a""b"'  "$(sql_ident 'a"b')"
check "conninfo_quote"        "'a b\\'c\\\\d'" "$(conninfo_quote "a b'c\\d")"
check "umask owner-only"      "0077"    "$(umask)"

parse_remote_url "postgres://alice:s%40fe@db.example.com:5433/mydb?sslmode=require"
check "parse host" "db.example.com" "$REMOTE_HOST"
check "parse port" "5433"           "$REMOTE_PORT"
check "parse user" "alice"          "$REMOTE_USER"
check "parse pass" "s@fe"           "$REMOTE_PASS"
check "parse db"   "mydb"           "$REMOTE_DB"
check "parse sslmode param" " sslmode='require'" "$REMOTE_PARAMS"
check "conninfo quotes values" \
    "host='db.example.com' port='5433' user='alice' dbname='my db' keepalives=1 keepalives_idle=60 keepalives_interval=15 keepalives_count=10 connect_timeout=30 sslmode='require'" \
    "$(make_conninfo "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER" "my db")"

parse_remote_url "postgres://alice:pw@db:5432/mydb?schema=public&ssl=true&password=x&sslpassword=y" 2>/dev/null
check "params: keep TLS, drop others and secrets" " sslmode='require'" "$REMOTE_PARAMS"

rm -f "$TMP" "$TMP.bak"

echo
echo "==> Summary: $PASS passed, $FAIL failed"
exit "$FAIL"
