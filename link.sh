#!/usr/bin/env bash
# Symlinks the files in this repo into $TARGET (default: $HOME).
# Links files individually (never a whole directory as one symlink), so this
# repo can safely share a target directory (e.g. ~/.config/hypr) with files
# managed by GNU Stow or anything else, without conflicting.
#
# Usage: ./link.sh
#
# Reads .linkignore in this directory: one regex per line (matched against
# the file's path relative to this directory), '#' starts a comment, blank
# lines are skipped.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-$HOME}"
IGNORE_FILE="$SRC/.linkignore"

link_count=0
skip_count=0

should_ignore() {
    local rel="$1"
    [ -f "$IGNORE_FILE" ] || return 1
    local pattern
    while IFS= read -r line; do
        pattern="${line%%#*}"
        pattern="$(echo -n "$pattern" | xargs)"
        [ -z "$pattern" ] && continue
        if [[ "$rel" =~ $pattern ]]; then
            return 0
        fi
    done < "$IGNORE_FILE"
    return 1
}

link_file() {
    local src_file="$1" rel="$2"
    local target_file="$TARGET/$rel"
    local target_dir
    target_dir="$(dirname "$target_file")"

    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        echo "mkdir:  $target_dir"
    fi

    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        if [ -L "$target_file" ] && [ "$(readlink -f "$target_file")" = "$(readlink -f "$src_file")" ]; then
            skip_count=$((skip_count + 1))
            return
        fi
        echo "SKIP:   $target_file already exists (not our symlink)"
        skip_count=$((skip_count + 1))
        return
    fi

    ln -s "$src_file" "$target_file"
    echo "link:   $target_file -> $src_file"
    link_count=$((link_count + 1))
}

while IFS= read -r -d '' file; do
    rel="${file#"$SRC"/}"
    should_ignore "$rel" && continue
    link_file "$file" "$rel"
done < <(find "$SRC" -type f -print0)

echo
echo "Done: ${link_count} linked, ${skip_count} skipped/already-linked."
