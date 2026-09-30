#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
set +e
output="$({
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_island_alert_screen.qml"
} 2>&1)"
test_status=$?
set -e
printf '%s\n' "$output"
[[ "$output" == *"ALERT_SCREEN_TEST_PASS"* ]]
[[ "$output" != *"ALERT_SCREEN_TEST_FAIL"* ]]
[[ "$test_status" -ne 124 ]]
