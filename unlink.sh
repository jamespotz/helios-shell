#!/usr/bin/env bash
# Removes Helios from $TARGET (default: $HOME) in one go: the symlinks
# link.sh made, the files Helios generates at runtime (theme exports), and its
# state and cache. Lists everything first and asks before deleting.
#
# Usage: ./unlink.sh [-y]
#
# Leaves your own app configs (tmux.conf, kitty.conf, ...) untouched; lines in
# them that still include a Helios file are listed at the end to remove by hand.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-$HOME}"

# Written by services/themeExport/*.js and older Helios versions.
generated=(
    .config/alacritty/themes/helios.toml
    .config/bat/themes/Helios.tmTheme
    .config/btop/themes/helios.theme
    .config/fish/conf.d/helios-colors.fish
    .config/fuzzel/themes/helios
    .config/ghostty/themes/helios
    .config/hypr/helios.lua
    .config/hypr/helios-custom-binds.lua
    .config/hypr/hypridle-helios.conf
    .config/kitty/themes/helios.conf
    .config/rofi/helios.rasi
    .config/tmux/helios.conf
    .config/vivaldi/helios
    .config/wezterm/colors/helios.toml
    .config/wofi/helios.css
    .config/zed/themes/helios.json
    .local/share/color-schemes/Helios.colors
    .local/state/helios
    .cache/helios
)

# App configs the exporters add an include/source line to.
includers=(
    .config/alacritty/alacritty.toml .config/bat/config .config/btop/btop.conf
    .config/fuzzel/fuzzel.ini .config/ghostty/config .config/hypr/hyprland.lua
    .config/hypr/hyprland.conf .config/kitty/kitty.conf .config/rofi/config.rasi
    .config/tmux/tmux.conf .config/wezterm/wezterm.lua .config/wofi/style.css
    .config/zed/settings.json .config/kdeglobals
)

doomed=()

# Symlinks into this repo, wherever link.sh put them.
link_target() {
    local t="$TARGET/$1"
    [ -L "$t" ] && [[ "$(readlink -f "$t")" == "$SRC"/* ]] && doomed+=("$t")
    return 0
}
link_target .config/quickshell/helios
while IFS= read -r -d '' file; do
    link_target "${file#"$SRC"/}"
done < <(find "$SRC" -path "$SRC/.git" -prune -o -path "$SRC/.config/quickshell/helios" -prune -o -type f -print0)

for rel in "${generated[@]}"; do
    t="$TARGET/$rel"
    # A symlink to another repo (e.g. ~/dotfiles) isn't Helios's to delete.
    if [ -L "$t" ] && [[ "$(readlink -f "$t")" != "$SRC"/* ]]; then
        echo "keep:   $t -> $(readlink "$t") (not this repo)"
        continue
    fi
    [ -e "$t" ] && doomed+=("$t")
done

if [ ${#doomed[@]} -eq 0 ]; then
    echo "Nothing to remove."
else
    printf 'remove: %s\n' "${doomed[@]}"
    if [ "${1:-}" != "-y" ]; then
        read -r -p "Delete these ${#doomed[@]} paths? [y/N] " answer
        [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    fi
    rm -rf -- "${doomed[@]}"
    # Drop directories link.sh created that are now empty; stops at the first non-empty parent.
    for p in "${doomed[@]}"; do
        rmdir -p --ignore-fail-on-non-empty "$(dirname "$p")" 2>/dev/null || true
    done
    echo "Removed ${#doomed[@]} paths."
fi

for rel in "${includers[@]}"; do
    t="$TARGET/$rel"
    [ -f "$t" ] && grep -n -i 'helios' "$t" | sed "s|^|still references helios: $t:|" || true
done
