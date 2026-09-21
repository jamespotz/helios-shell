#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

cp -a "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_wallpaper_rescan_on_open.qml" "$test_root/helios/tst_wallpaper_rescan_on_open.qml"

set +e
output="$({
    WALLPAPER_RESCAN_TEST_DIR="$test_root/wallpapers" \
    HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$test_root/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_wallpaper_rescan_on_open.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"

if [[ "$output" != *"WALLPAPER_RESCAN_ON_OPEN_TEST_PASS"* ]] || [[ "$output" == *"WALLPAPER_RESCAN_ON_OPEN_TEST_FAIL"* ]]; then
    exit 1
fi

if [[ "$test_status" -eq 124 ]]; then
    printf 'Wallpaper rescan-on-open test timed out\n' >&2
    exit 1
fi
