#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
library="$repo_root/.config/quickshell/helios/services/WallpaperLibrary.qml"

grep -q 'property var wallpapers: \[\]' "$library"
grep -q 'sortOrder: index' "$library"
grep -q 'root.images = root._activeFirst(root._storedImages())' "$library"
grep -q 'root.images = root._activeFirst(root._mergeScan(scannedImages))' "$library"
grep -q 'root._storeImages(root.images, false)' "$library"
grep -q 'if (exitCode !== 0) return' "$library"

printf 'WALLPAPER_LIBRARY_TEST_PASS\n'
