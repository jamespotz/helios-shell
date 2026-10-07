#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# Private runtime dir: the test bus starts its own portals, which would
# otherwise take over the real session's $XDG_RUNTIME_DIR/doc mount.
mkdir -m 700 "$test_root/runtime"
export XDG_RUNTIME_DIR="$test_root/runtime"
cp -a "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_launcher_widget.qml" "$test_root/helios/tst_launcher_widget.qml"
cp "$repo_root/.config/quickshell/helios/data/linux.svg" "$test_root/logo#1?50%.svg"
set +e
output="$(PATH="$repo_root/tests/fixtures/launcher-icon:$PATH" HELIOS_TEST_ICON="$test_root/logo#1?50%.svg" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" QT_QPA_PLATFORM=offscreen timeout 5s dbus-run-session -- qs --no-color --path "$test_root/helios/tst_launcher_widget.qml" 2>&1)"
test_status=$?
set -e
printf '%s\n' "$output"
[[ "$output" == *"LAUNCHER_WIDGET_TEST_PASS"* ]]
[[ "$output" != *"LAUNCHER_WIDGET_TEST_FAIL"* ]]
[[ "$test_status" -ne 124 ]]
[[ "$output" != *"ERROR qml:"* ]]
