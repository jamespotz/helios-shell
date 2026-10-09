#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -m 700 "$test_root/runtime"
mkdir "$test_root/bin"
export XDG_RUNTIME_DIR="$test_root/runtime"
cat > "$test_root/bin/slurp" <<'EOF'
#!/bin/sh
printf '0,0 10x10\n'
EOF
cat > "$test_root/bin/grim" <<'EOF'
#!/bin/sh
for last do :; done
printf 'fake image' > "$last"
EOF
cat > "$test_root/bin/tesseract" <<'EOF'
#!/bin/sh
if [ "${OCR_PRIVACY_EMPTY:-0}" != 1 ]; then printf 'Private OCR text\nsecond line\n'; fi
EOF
cat > "$test_root/bin/wl-copy" <<'EOF'
#!/bin/sh
cat >> "$OCR_PRIVACY_TEST_ROOT/copied"
EOF
for tool in notify-send canberra-gtk-play; do
    printf '#!/bin/sh\nexit 0\n' > "$test_root/bin/$tool"
done
chmod +x "$test_root/bin/"*
PATH="$test_root/bin:$PATH" OCR_PRIVACY_TEST_ROOT="$test_root" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" XDG_CACHE_HOME="$test_root/cache" XDG_STATE_HOME="$test_root/state" QT_QPA_PLATFORM=offscreen QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" timeout 5s dbus-run-session -- qs --no-color --path "$repo_root/tests/qml/tst_screenshot_ocr_privacy.qml" > "$test_root/log" 2>&1 || true
cat "$test_root/log"
rg -q OCR_PRIVACY_TEST_PASS "$test_root/log"
if [[ "${OCR_PRIVACY_EMPTY:-0}" == 1 ]]; then
    [[ ! -s "$test_root/copied" ]]
else
[[ "$(cat "$test_root/copied")" == $'Private OCR text\nsecond line\nPrivate OCR text\nsecond line' ]]
fi
# Captures may remain; plaintext must stay in memory only.
! find "$test_root" -type f -name '*ocr*.txt' | rg .
! rg -q '/tmp/helios-screenshot-ocr.txt' "$repo_root/.config/quickshell/helios/services/Screenshot.qml"
