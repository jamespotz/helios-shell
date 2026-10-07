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
cp "$repo_root/tests/qml/"tst_turntable*.qml "$test_root/helios/"
run_case() {
    local name="$1" marker="$2" phase="${3:-}" output status
    set +e
    output="$(env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
        XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" \
        DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_root/no-system-bus" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$test_root/helios" \
        HELIOS_TURNTABLE_PHASE="$phase" \
        timeout 10s dbus-run-session -- qs --no-color --path "$test_root/helios/$name.qml" 2>&1)"
    status=$?
    set -e
    if [[ "$output" != *"${marker}_PASS"* || "$output" == *"${marker}_FAIL"* || "$output" == *" ERROR "* || "$status" -eq 124 ]]; then
        printf '%s\n' "$output"
        return 1
    fi
    printf 'PASS %s %s\n' "$name" "$phase"
}
for phase in write read; do run_case tst_turntable_preferences TURNTABLE_PREFERENCES_TEST "$phase"; done
run_case tst_turntable_visual TURNTABLE_VISUAL_TEST
run_case tst_turntable_designs TURNTABLE_DESIGNS_TEST
run_case tst_turntable_settings TURNTABLE_SETTINGS_TEST
