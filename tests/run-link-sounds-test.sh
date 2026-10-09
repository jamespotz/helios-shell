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
cp "$repo_root/tests/qml/tst_link_sounds.qml" "$test_root/helios/tst_link_sounds.qml"
# Keep UI activation tests away from the session's Bluetooth adapter.
cat > "$test_root/helios/services/Bluetooth.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool scanning: false
    property bool discoverable: false
    property var lowBatteryAlert: null
    property string lastError: ""
    readonly property var state: ({powered: true, available: true, scanning: scanning,
        discoverable: discoverable, devices: [], lastError: ""})
    signal deviceConnectionChanged(bool connected)
    function setScanning(value) { scanning = value }
    function setDiscoverable(value) { discoverable = value }
    function setActive(value) {}
    function refreshAll() {}
}
QML
mkdir -p "$test_root/bin"
cat > "$test_root/bin/canberra-gtk-play" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$HELIOS_SOUND_CALLS"
STUB
cp "$test_root/bin/canberra-gtk-play" "$test_root/bin/pactl"
cp "$test_root/bin/canberra-gtk-play" "$test_root/bin/xdg-open"
cp "$test_root/bin/canberra-gtk-play" "$test_root/bin/nmcli"
chmod +x "$test_root/bin/canberra-gtk-play" "$test_root/bin/pactl" "$test_root/bin/xdg-open" "$test_root/bin/nmcli"
export PATH="$test_root/bin:$PATH"
export HELIOS_SOUND_CALLS="$test_root/sound-calls"
set +e
output="$({
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" QML_IMPORT_PATH="$test_root/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_link_sounds.qml"
} 2>&1)"
test_status=$?
set -e
printf '%s\n' "$output"
[[ "$output" == *"LINK_SOUNDS_TEST_PASS"* ]]
[[ "$output" != *"LINK_SOUNDS_TEST_FAIL"* ]]
[[ "$test_status" -ne 124 ]]
[[ "$output" != *"ERROR qml:"* ]]
