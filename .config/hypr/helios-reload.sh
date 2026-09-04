#!/bin/sh
# Reload/relaunch helios — bound to SUPER + SHIFT + R in helios-binds.lua.
# Kept as its own script (not an inline `cmd1; cmd2` in the Lua bind) because
# this Hyprland fork's config-load-time bind marshalling didn't run the
# semicolon-chained inline version, even though the exact same string worked
# fine when run directly or via a live `hyprctl dispatch`.
pkill -f 'quickshell -c helios'
while pgrep -f 'quickshell -c helios' >/dev/null; do sleep 0.05; done
# Caps glibc malloc arenas — without this, repeated alloc/free churn
# fragments per-thread arenas and RSS creeps up over a session without
# ever being freed back.
export MALLOC_ARENA_MAX=1
exec quickshell -c helios -d
