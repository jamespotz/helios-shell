#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat > "$test_root/bin/slurp" <<'EOF'
#!/bin/sh
sleep 1
EOF
chmod +x "$test_root/bin/slurp"

set +e
output="$({
    PATH="$test_root/bin:$PATH" \
    OCR_IPC_TEST_RESULT="$test_root/result" \
    HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_screenshot_ocr_ipc.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"
[[ "$test_status" -ne 124 ]]
[[ -f "$test_root/result" ]]
[[ "$(cat "$test_root/result")" == "region:true:true:true" ]]
