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
grep -q 'carousel.positionViewAtIndex(carousel.currentIndex, ListView.Beginning)' "$carousel"
if grep -q 'if (carousel.currentIndex === idx) return' "$carousel"; then
    printf 'WALLPAPER_CAROUSEL_TEST_FAIL: async model positioning skipped\n' >&2
    exit 1
fi
grep -q 'onClicked: carousel.browse(carousel.currentIndex - 1)' "$carousel"
grep -q 'onClicked: carousel.browse(carousel.currentIndex + 1)' "$carousel"
grep -q 'readonly property bool browsed: ListView.isCurrentItem' "$carousel"
grep -q 'border.width: thumb.browsed ? 2 : thumb.selected ? 1 : 0' "$carousel"
if grep -q 'onClicked: carousel.choose(carousel.currentIndex' "$carousel"; then
    printf 'WALLPAPER_CAROUSEL_TEST_FAIL: navigation applies wallpaper\n' >&2
    exit 1
fi
printf 'WALLPAPER_CAROUSEL_TEST_PASS\n'
