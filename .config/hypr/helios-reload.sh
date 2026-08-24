#!/bin/sh
# Reload/relaunch helios — bound to SUPER + SHIFT + R in helios-binds.lua.
# Kept as its own script (not an inline `cmd1; cmd2` in the Lua bind) because
# this Hyprland fork's config-load-time bind marshalling didn't run the
# semicolon-chained inline version, even though the exact same string worked
# fine when run directly or via a live `hyprctl dispatch`.
pkill -f 'quickshell -c helios'
exec quickshell -c helios -d
