#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
cp -a "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_island_satellite.qml" "$test_root/helios/tst_island_satellite.qml"
# Selection tests need caffeine state, never a real hypridle process.
cat > "$test_root/helios/services/IdleInhibit.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject { property bool enabled: true; property bool inhibited: false }
QML
set +e
output="$({
    HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" QML_IMPORT_PATH="$test_root/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_island_satellite.qml"
} 2>&1)"
test_status=$?
set -e
printf '%s\n' "$output"
[[ "$output" == *"ISLAND_SATELLITE_TEST_PASS"* ]]
[[ "$output" != *"ISLAND_SATELLITE_TEST_FAIL"* ]]
[[ "$test_status" -ne 124 ]]
[[ "$output" != *"ERROR qml:"* ]]
