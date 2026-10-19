#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
picker="$repo_root/.config/quickshell/helios/modules/island/WallpaperPicker.qml"

if grep -q 'target: Wallpaper$' "$picker"; then
    printf 'WALLPAPER_PICKER_TEST_FAIL: stale startup sync target\n' >&2
    exit 1
fi

grep -q 'target: WallpaperLibrary$' "$picker"
grep -q 'function onImagesChanged() { grid.syncToCurrent() }' "$picker"
grep -q 'function onPathChanged() { grid.syncToCurrent() }' "$picker"
grep -q 'grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)' "$picker"
if grep -q 'if (grid.currentIndex === idx) return' "$picker"; then
    printf 'WALLPAPER_PICKER_TEST_FAIL: async model positioning skipped\n' >&2
    exit 1
fi
# Arrow keys and hover only preview; only click/Return/Space apply.
grep -q 'Keys.onDownPressed: browse(currentIndex + root.columns)' "$picker"
grep -q 'Keys.onReturnPressed: choose(currentIndex)' "$picker"
grep -q 'onClicked: grid.choose(tile.index)' "$picker"
grep -q 'readonly property int previewIndex: hoveredIndex >= 0 ? hoveredIndex : grid.currentIndex' "$picker"
if grep -qE 'Keys\.on(Left|Right|Up|Down)Pressed: choose' "$picker" || grep -q 'onContainsMouseChanged:.*choose' "$picker"; then
    printf 'WALLPAPER_PICKER_TEST_FAIL: navigation applies wallpaper\n' >&2
    exit 1
fi
printf 'WALLPAPER_PICKER_TEST_PASS\n'
