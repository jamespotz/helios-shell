#!/bin/sh
# Reload/relaunch helios — bound to SUPER + SHIFT + R in helios-binds.lua.
# Kept as its own script (not an inline `cmd1; cmd2` in the Lua bind) because
# this Hyprland fork's config-load-time bind marshalling didn't run the
# semicolon-chained inline version, even though the exact same string worked
# fine when run directly or via a live `hyprctl dispatch`.
pkill -f '^quickshell -c helios'
# Give it ~5s to exit cleanly, then force it so a hung instance can't
# block the relaunch forever.
i=0
while pgrep -f '^quickshell -c helios' >/dev/null; do
    i=$((i + 1))
    [ "$i" -eq 100 ] && pkill -KILL -f '^quickshell -c helios'
    sleep 0.05
done
# glibc malloc fragments under the QML engine's alloc/free churn and never
# hands the pages back, so RSS creeps up over a session (confirmed: ~1.1GB+
# and still climbing after a few minutes without this). jemalloc doesn't
# have that behavior — same instance stayed flat around ~270MB.
export LD_PRELOAD=/lib64/libjemalloc.so.2
# Third-party .desktop files with non-spec escapes (swappy's Exec) log a
# warning on every entry rescan — thousands per session, none actionable.
export QT_LOGGING_RULES="${QT_LOGGING_RULES:+$QT_LOGGING_RULES;}quickshell.desktopentry.warning=false"
# App icons resolve through Qt's icon theme, which the session's Qt platform
# theme may not set. Follow the GTK icon theme (what nwg-look writes) so
# helios matches the rest of the desktop; picked up on each relaunch.
icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
[ -n "$icon_theme" ] && export QS_ICON_THEME="$icon_theme"
exec quickshell -c helios -d
