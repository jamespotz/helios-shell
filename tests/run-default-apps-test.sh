#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# Private runtime dir: the test bus starts its own portals, which would
# otherwise take over the real session's $XDG_RUNTIME_DIR/doc mount.
mkdir -m 700 "$test_root/runtime"
export XDG_RUNTIME_DIR="$test_root/runtime"

# One fake image viewer, registered for image/png and set as its default.
mkdir -p "$test_root/data/applications" "$test_root/config"
printf '[Desktop Entry]\nType=Application\nName=Fake Viewer\nExec=/usr/bin/true %%f\nMimeType=image/png;\n' \
    > "$test_root/data/applications/fake-viewer.desktop"
printf '[Default Applications]\nimage/png=fake-viewer.desktop\n' > "$test_root/config/mimeapps.list"
# xdg-mime and gio both look handlers up in mimeinfo.cache.
update-desktop-database "$test_root/data/applications"

set +e
output="$({
    HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    XDG_DATA_HOME="$test_root/data" \
    XDG_DATA_DIRS="$test_root/data:/usr/share" \
    QT_QPA_PLATFORM="offscreen" \
    HYPRLAND_INSTANCE_SIGNATURE="helios-test-none" \
    QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_default_apps.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"

if [[ "$output" != *"DEFAULT_APPS_TEST_PASS"* ]] || [[ "$output" == *"DEFAULT_APPS_TEST_FAIL"* ]]; then
    exit 1
fi

if [[ "$test_status" -eq 124 ]]; then
    printf 'Default apps test timed out\n' >&2
    exit 1
fi
