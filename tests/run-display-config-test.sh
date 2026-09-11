#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin"

cat > "$test_root/hyprland.lua" <<'EOF'
hl.monitor({
  output = "DP-1",
  mode = "1920x1080@60.00Hz",
  position = "0x0",
  scale = 1,
})
EOF

cat > "$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "reload" ]]; then
    exit 0
fi
if [[ "$1" == "monitors" && "$2" == "-j" ]]; then
    printf '[{"name":"DP-1","width":2560,"height":1440,"availableModes":[],"colorManagementPreset":"srgb","vrr":false}]\n'
    exit 0
fi
exit 1
EOF
chmod +x "$test_root/bin/hyprctl"

PATH="$test_root/bin:$PATH" python3 \
    "$repo_root/.config/quickshell/helios/modules/bar/display-config.py" \
    --config "$test_root/hyprland.lua" \
    --output DP-1 \
    --mode 2560x1440@144.00Hz \
    --scale 1.25 \
    --vrr 3 \
    --cm hdr \
    --bitdepth 10

grep -Fq 'mode = "2560x1440@144.00Hz"' "$test_root/hyprland.lua"
grep -Fq 'scale = 1.25' "$test_root/hyprland.lua"
grep -Fq 'vrr = 3' "$test_root/hyprland.lua"
grep -Fq 'cm = "hdr"' "$test_root/hyprland.lua"
grep -Fq 'bitdepth = 10' "$test_root/hyprland.lua"

query_output="$(PATH="$test_root/bin:$PATH" python3 \
    "$repo_root/.config/quickshell/helios/modules/bar/display-config.py" \
    --config "$test_root/hyprland.lua" \
    --query --json --all)"
python3 -c 'import json, sys; monitor = json.load(sys.stdin)[0]; assert monitor["vrrMode"] == 3; assert monitor["colorManagementPreset"] == "hdr"; assert monitor["configuredBitdepth"] == 10' <<< "$query_output"

if PATH="$test_root/bin:$PATH" python3 \
    "$repo_root/.config/quickshell/helios/modules/bar/display-config.py" \
    --config "$test_root/hyprland.lua" \
    --output DP-1 --scale 1.3 2>/dev/null; then
    printf 'Invalid scale was accepted\n' >&2
    exit 1
fi

printf 'DISPLAY_CONFIG_TEST_PASS\n'
