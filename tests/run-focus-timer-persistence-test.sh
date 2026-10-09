#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -m 700 "$test_root/runtime"
for mode in running-write running-read paused-write paused-read expired-write expired-read dismissed-read break-write break-read pomodoro-write pomodoro-read; do
    set +e
    output="$(HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" HELIOS_TIMER_MODE="$mode" QT_QPA_PLATFORM=offscreen QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_focus_timer_persistence.qml" 2>&1)"
    status=$?
    set -e
    printf '%s\n' "$output"
    [[ "$output" == *"FOCUS_TIMER_PERSISTENCE_TEST_PASS"* ]]
    [[ "$output" != *"FOCUS_TIMER_PERSISTENCE_TEST_FAIL"* ]]
    [[ "$status" -ne 124 ]]
done
