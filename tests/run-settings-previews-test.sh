#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
cp -a "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_settings_previews.qml" "$test_root/helios/"
set +e
output="$(env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" \
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_root/no-system-bus" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$test_root/helios" \
    timeout 15s dbus-run-session -- qs --no-color --path "$test_root/helios/tst_settings_previews.qml" 2>&1)"
status=$?
set -e
if [[ "$output" != *"SETTINGS_PREVIEWS_TEST_PASS"* || "$output" == *"SETTINGS_PREVIEWS_TEST_FAIL"* || "$output" == *"ERROR qml:"* || "$output" == *"Failed to load configuration"* || "$output" == *"Unable to assign"* || "$output" == *"Grid contains more visible items"* || "$status" -eq 124 ]]; then
    printf '%s\n' "$output"
    exit 1
fi
printf 'PASS settings previews\n'
