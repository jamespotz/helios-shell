#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# Private runtime dir: the test bus starts its own portals, which would
# otherwise take over the real session's $XDG_RUNTIME_DIR/doc mount.
mkdir -m 700 "$test_root/runtime"
export XDG_RUNTIME_DIR="$test_root/runtime"

# Exercise real setters and storage, with system actions isolated from the session.
mkdir -p "$test_root/bin" "$test_root/home/wallpapers" "$test_root/home/.config/quickshell/helios/data"
mkdir -p "$test_root/home/.local/share/applications" "$test_root/config"
cp "$repo_root/.config/quickshell/helios/data/themes.json" "$test_root/home/.config/quickshell/helios/data/"
touch "$test_root/home/wallpapers/a.png" "$test_root/home/wallpapers/b.png"
for command in pkill hypridle wlsunset hyprctl gsettings wpctl tmux; do
    printf '#!/bin/sh\nexit 0\n' > "$test_root/bin/$command"
    chmod +x "$test_root/bin/$command"
done
for category in browser filemanager editor; do
    cat > "$test_root/home/.local/share/applications/persistence-$category.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Persistence $category
Exec=/usr/bin/true
EOF
done

failed=0
scopes=("${@}")
if [[ ${#scopes[@]} -eq 0 ]]; then scopes=(config dock shell automatic-dnd idle nightlight weather theme focus automations wallpaper default-apps); fi
for scope in "${scopes[@]}"; do
    for phase in write read read; do
        set +e
        output="$({
            env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
                PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
                XDG_DATA_HOME="$test_root/home/.local/share" \
                XDG_CACHE_HOME="$test_root/cache/$scope" XDG_STATE_HOME="$test_root/state/$scope" \
                DBUS_SYSTEM_BUS_ADDRESS="unix:path=$test_root/no-system-bus" QT_QPA_PLATFORM="offscreen" \
                QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
                HELIOS_SETTINGS_TEST_SCOPE="$scope" HELIOS_SETTINGS_TEST_PHASE="$phase" \
                timeout 8s dbus-run-session -- qs --no-color --path "$repo_root/tests/qml/tst_settings_persistence.qml"
        } 2>&1)"
        test_status=$?
        set -e
        if [[ "$output" != *"SETTINGS_PERSISTENCE_TEST_PASS"* || "$output" == *"SETTINGS_PERSISTENCE_TEST_FAIL"* || "$test_status" -eq 124 ]]; then
            printf '%s\n' "$output"
            failed=1
            break
        fi
        printf 'PASS %s %s\n' "$scope" "$phase"
    done
done
exit "$failed"
