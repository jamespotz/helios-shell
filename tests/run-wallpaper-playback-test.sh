#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
playback="$repo_root/.config/quickshell/helios/services/WallpaperPlayback.qml"
library="$repo_root/.config/quickshell/helios/services/WallpaperLibrary.qml"
shell="$repo_root/.config/quickshell/helios/shell.qml"

if grep -q 'WallpaperPlayback.apply(root.path, true)' "$library"; then
    printf 'WALLPAPER_PLAYBACK_TEST_FAIL: opening library reapplies saved wallpaper\n' >&2
    exit 1
fi

if grep -q 'command: \["awww-daemon"\]' "$playback"; then
    printf 'WALLPAPER_PLAYBACK_TEST_FAIL: quickshell owns wallpaper daemon\n' >&2
    exit 1
fi

grep -q '"systemd-run", "--user", "--collect", "--quiet"' "$playback"
grep -q '"--unit=helios-awww-daemon", "awww-daemon"' "$playback"
grep -q 'daemon.running = true' "$playback"
grep -q 'signal settingsLoaded()' "$library"
grep -q 'onLoaded: {' "$library"
grep -q 'root.settingsLoaded()' "$library"
grep -q 'function onSettingsLoaded()' "$shell"
grep -q 'WallpaperPlayback.apply(WallpaperLibrary.path, true)' "$shell"
printf 'WALLPAPER_PLAYBACK_TEST_PASS\n'
