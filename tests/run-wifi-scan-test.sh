#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# Private runtime dir: the test bus starts its own portals, which would
# otherwise take over the real session's $XDG_RUNTIME_DIR/doc mount.
mkdir -m 700 "$test_root/runtime"
export XDG_RUNTIME_DIR="$test_root/runtime"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_root/no-system-bus"
cp -a "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_wifi_scan.qml" "$test_root/helios/tst_wifi_scan.qml"
mkdir -p "$test_root/bin"
cat > "$test_root/bin/canberra-gtk-play" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$HELIOS_SOUND_CALLS"
STUB
cp "$test_root/bin/canberra-gtk-play" "$test_root/bin/pactl"
chmod +x "$test_root/bin/canberra-gtk-play" "$test_root/bin/pactl"
cat > "$test_root/bin/nmcli" <<'STUB'
#!/bin/sh
case "$*" in
    "device wifi rescan") sleep 0.3 ;;
    *"device wifi list"*) printf ':Test:80:WPA2\n' ;;
esac
STUB
chmod +x "$test_root/bin/nmcli"
export PATH="$test_root/bin:$PATH"
export HELIOS_SOUND_CALLS="$test_root/sound-calls"
set +e
output="$({
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" QML_IMPORT_PATH="$test_root/helios" \
        timeout 8s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_wifi_scan.qml"
} 2>&1)"
test_status=$?
set -e
printf '%s\n' "$output"
[[ "$output" == *"WIFI_SCAN_TEST_PASS"* ]]
[[ "$output" != *"WIFI_SCAN_TEST_FAIL"* ]]
[[ "$test_status" -ne 124 ]]
[[ "$output" != *"ERROR qml:"* ]]
