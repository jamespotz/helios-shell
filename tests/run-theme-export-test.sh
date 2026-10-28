#!/usr/bin/env bash
# Every app's theme export against stored copies in tests/fixtures/theme-export.
# UPDATE_FIXTURES=1 rewrites the stored copies from the current output.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixtures="$repo_root/tests/fixtures/theme-export"
node "$repo_root/tests/js/theme-export-audit.test.cjs"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# Private runtime dir: the test bus starts its own portals, which would
# otherwise take over the real session's $XDG_RUNTIME_DIR/doc mount.
mkdir -m 700 "$test_root/runtime" "$test_root/out"
export XDG_RUNTIME_DIR="$test_root/runtime"

set +e
output="$({
    HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    HELIOS_THEME_OUT="$test_root/out" \
    QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_theme_export.qml"
} 2>&1)"
test_status=$?
set -e

if [[ "$output" != *"THEME_EXPORT_TEST_PASS"* ]] || [[ "$output" == *"THEME_EXPORT_TEST_FAIL"* ]] || [[ "$test_status" -eq 124 ]]; then
    printf '%s\n' "$output"
    exit 1
fi

if [[ "${UPDATE_FIXTURES:-}" == 1 ]]; then
    rm -rf "$fixtures"
    cp -r "$test_root/out" "$fixtures"
    printf 'Updated %s\n' "$fixtures"
    exit 0
fi

diff -ru "$fixtures" "$test_root/out"
printf 'THEME_EXPORT_TEST_PASS\n'
