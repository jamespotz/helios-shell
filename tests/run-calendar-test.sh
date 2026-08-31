#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

set +e
output="$({
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_calendar.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"

if [[ "$output" != *"CALENDAR_TEST_PASS"* ]] || [[ "$output" == *"CALENDAR_TEST_FAIL"* ]]; then
    exit 1
fi

if [[ "$test_status" -eq 124 ]]; then
    printf 'Calendar test timed out\n' >&2
    exit 1
fi
