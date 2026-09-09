#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
carousel="$repo_root/.config/quickshell/helios/modules/bar/WallpaperCarousel.qml"

if grep -q 'target: Wallpaper$' "$carousel"; then
    printf 'WALLPAPER_CAROUSEL_TEST_FAIL: stale startup sync target\n' >&2
    exit 1
fi

grep -q 'target: WallpaperLibrary$' "$carousel"
grep -q 'function onImagesChanged() { carousel.syncToCurrent() }' "$carousel"
grep -q 'function onPathChanged() { carousel.syncToCurrent() }' "$carousel"
printf 'WALLPAPER_CAROUSEL_TEST_PASS\n'
