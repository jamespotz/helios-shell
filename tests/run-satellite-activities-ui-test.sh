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
cp "$repo_root/tests/qml/tst_satellite_activities_ui.qml" "$test_root/helios/tst_satellite_activities_ui.qml"
# Replace system boundaries so UI actions cannot alter the desktop session.
cat > "$test_root/helios/services/MicActivity.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject { property bool isSystemMicActive: true; property var activeApps: ["Discord"] }
QML
cat > "$test_root/helios/services/CameraActivity.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject { property bool isSystemCameraActive: true; property var activeApps: ["Firefox"] }
QML
cat > "$test_root/helios/services/FocusModes.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property string activeId: "focus"
    property int endCalls: 0
    property var presets: [{id: "focus", name: "Focus", icon: "center_focus_strong"}, {id: "writing", name: "Writing", icon: "edit"}]
    function toggle(preset) { activeId = activeId === preset.id ? "" : preset.id; }
    function deactivate() { endCalls++; activeId = ""; }
}
QML
cat > "$test_root/helios/services/IdleInhibit.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool enabled: true
    property bool inhibited: true
    property int toggleCalls: 0
    function toggleInhibit() { toggleCalls++; inhibited = !inhibited; }
}
QML
set +e
output="$({
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM=offscreen QML_IMPORT_PATH="$test_root/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_satellite_activities_ui.qml"
} 2>&1)"
test_status=$?
set -e
printf '%s\n' "$output"
[[ "$output" == *"SATELLITE_ACTIVITIES_UI_TEST_PASS"* ]]
[[ "$output" != *"SATELLITE_ACTIVITIES_UI_TEST_FAIL"* ]]
[[ "$output" != *"ERROR qml:"* ]]
[[ "$test_status" -ne 124 ]]
