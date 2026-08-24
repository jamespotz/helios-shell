#!/usr/bin/env bash
# Removes symlinks in $TARGET (default: $HOME) that link.sh created for the
# files in this repo. Only removes a target if it's a symlink resolving back
# into this repo — never touches real files, so it's safe to run even if
# some targets were since replaced by GNU Stow or anything else.
#
# Usage: ./unlink.sh
#
# Reads .linkignore in this directory: one regex per line (matched against
# the file's path relative to this directory), '#' starts a comment, blank
# lines are skipped.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-$HOME}"
IGNORE_FILE="$SRC/.linkignore"

unlink_count=0
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

unlink_file() {
    local src_file="$1" rel="$2"
    local target_file="$TARGET/$rel"

    if [ ! -L "$target_file" ]; then
        skip_count=$((skip_count + 1))
        return
    fi

    if [ "$(readlink -f "$target_file")" != "$(readlink -f "$src_file")" ]; then
        echo "SKIP:   $target_file (symlink points elsewhere, not ours)"
        skip_count=$((skip_count + 1))
        return
    fi

    rm "$target_file"
    echo "unlink: $target_file"
    unlink_count=$((unlink_count + 1))
}

while IFS= read -r -d '' file; do
    rel="${file#"$SRC"/}"
    should_ignore "$rel" && continue
    unlink_file "$file" "$rel"
done < <(find "$SRC" -type f -print0)

echo
echo "Done: ${unlink_count} unlinked, ${skip_count} skipped."
