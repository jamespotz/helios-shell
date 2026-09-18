#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat > "$test_root/bin/notify-send" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$SCREENSHOT_TEST_ROOT/notification"
EOF
cat > "$test_root/bin/canberra-gtk-play" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$SCREENSHOT_TEST_ROOT/sound"
EOF
chmod +x "$test_root/bin/notify-send" "$test_root/bin/canberra-gtk-play"

set +e
output="$({
    PATH="$test_root/bin:$PATH" \
    SCREENSHOT_TEST_ROOT="$test_root" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_screenshot_feedback.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"
[[ "$test_status" -ne 124 ]]
[[ "$(cat "$test_root/notification")" == $'--app-name=Helios\n--icon=camera-photo\nScreenshot taken\nScreen-20260919-120000.png' ]]
[[ "$(cat "$test_root/sound")" == '--id=screen-capture' ]]
