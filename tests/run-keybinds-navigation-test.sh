#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

cp -a "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_keybinds_navigation.qml" "$test_root/helios/tst_keybinds_navigation.qml"

set +e
output="$({
    HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$test_root/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_keybinds_navigation.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"

if [[ "$output" != *"KEYBINDS_NAVIGATION_TEST_PASS"* ]] || [[ "$output" == *"KEYBINDS_NAVIGATION_TEST_FAIL"* ]]; then
    exit 1
fi

if [[ "$test_status" -eq 124 ]]; then
    printf 'Keybinds navigation test timed out\n' >&2
    exit 1
fi
