#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# Private runtime dir: the test bus starts its own portals, which would
# otherwise take over the real session's $XDG_RUNTIME_DIR/doc mount.
mkdir -m 700 "$test_root/runtime"
export XDG_RUNTIME_DIR="$test_root/runtime"

cp -r "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_destination_keyboard.qml" "$test_root/helios/"
python3 - "$test_root/helios" <<'PYTHON'
from pathlib import Path
import sys
root = Path(sys.argv[1]) / "services"
def stub(name, body):
    (root / (name + ".qml")).write_text("pragma Singleton\nimport QtQuick\nQtObject {\n" + body + "\n}\n")
stub("DisplaySettings", """
property bool loading: false
property var monitors: [{name: "Test", description: "Test display", disabled: false, width: 1920, height: 1080, refreshRate: 60, scale: 1, vrrMode: 0, colorManagementPreset: ""}]
function refresh() {}
function queryModes(name) {}
function modeState(name) { return {loading: false, modes: ["1920x1080@60.00Hz"]} }
function validScales(w, h) { return [1] }
property int activationCount: 0
function setResolutionMode(name, mode) { activationCount++ }
function setScale(name, value) {}
function setVrr(name, value) {}
function setHdr(name, value) {}
""")
stub("Themes", """
property string mode: "preset"
property string presetName: "test"
property bool generating: false
property bool dynamicDark: true
property string lastError: ""
property string paletteScheme: "test"
property var schemeOptions: []
property var presetOrder: ["test"]
property var presets: ({test: {label: "Test", surface: "#222222", surfaceHigh: "#333333", background: "#111111", accent: "#ffffff", text: "#ffffff"}})
function currentLabel() { return "Test" }
function isDark(color) { return true }
property int activationCount: 0
function applyPreset(name) { activationCount++ }
function applyDynamic() {}
function setDynamicMode(value) {}
function setPaletteScheme(value) {}
""")
stub("FocusModes", """
property string activeId: ""
property var presets: [{id: "test", name: "Test focus", icon: "work", apps: []}]
property int activationCount: 0
function toggle(preset) { activationCount++ }
function updatePreset(id, patch) {}
function removePreset(id) {}
function addPreset() { return presets[0] }
""")
stub("Notifications", """
property var state: ({history: [{id: 1, summary: "Test notification", body: "", time: new Date()}]})
property int activationCount: 0
function open(id) { activationCount++ }
function clearHistory() {}
""")
stub("ScreenRecorder", """
property string mode: "fullscreen"
property string modeFullscreen: "fullscreen"
property string modeWindow: "window"
property string modeRegion: "region"
property bool recording: false
property bool starting: false
property bool captureAudio: false
property string lastOutputPath: ""
property string lastThumbnailPath: ""
property string elapsedLabel: "00:00"
property string outputDir: "/tmp"
function verifyLastOutputPath() {}
function setMode(value) { mode = value }
property int activationCount: 0
function toggle(screen) { activationCount++ }
function setCaptureAudio(value) {}
function openFolder() {}
function playLast() {}
function chooseOutputDir() {}
""")
# Replace the system-bus PowerProfiles API inside the disposable copy.
power = Path(sys.argv[1]) / "modules/island/keyboardpower"
power.mkdir()
(power / "qmldir").write_text("singleton PowerProfile 1.0 PowerProfile.qml\nsingleton PowerProfiles 1.0 PowerProfiles.qml\n")
(power / "PowerProfile.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { readonly property int powerSaver: 0; readonly property int balanced: 1; readonly property int performance: 2 }\n")
(power / "PowerProfiles.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property int profile: 1; property bool hasPerformanceProfile: true; property var holds: [] }\n")
destination = power.parent / "PowerDestination.qml"
destination.write_text(destination.read_text().replace("import Quickshell.Services.UPower", 'import "keyboardpower"').replace("PowerProfile.PowerSaver", "PowerProfile.powerSaver").replace("PowerProfile.Balanced", "PowerProfile.balanced").replace("PowerProfile.Performance", "PowerProfile.performance"))
PYTHON
set +e
output="$({
    HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$test_root/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_destination_keyboard.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output" | rg 'TEST_|ERROR qml|WARN qml' || true

if [[ "$output" != *"DESTINATION_KEYBOARD_TEST_PASS"* ]] || [[ "$output" == *"DESTINATION_KEYBOARD_TEST_FAIL"* ]]; then
    exit 1
fi

if [[ "$test_status" -eq 124 ]]; then
    printf 'DESTINATION_KEYBOARD test timed out\n' >&2
    exit 1
fi

[[ "$output" != *"ERROR qml:"* ]]
