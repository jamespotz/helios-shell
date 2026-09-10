#!/bin/sh
# Reload/relaunch helios — bound to SUPER + SHIFT + R in helios-binds.lua.
# Kept as its own script (not an inline `cmd1; cmd2` in the Lua bind) because
# this Hyprland fork's config-load-time bind marshalling didn't run the
# semicolon-chained inline version, even though the exact same string worked
# fine when run directly or via a live `hyprctl dispatch`.
pkill -f 'quickshell -c helios'
while pgrep -f 'quickshell -c helios' >/dev/null; do sleep 0.05; done
# glibc malloc fragments under the QML engine's alloc/free churn and never
# hands the pages back, so RSS creeps up over a session (confirmed: ~1.1GB+
# and still climbing after a few minutes without this). jemalloc doesn't
# have that behavior — same instance stayed flat around ~270MB.
export LD_PRELOAD=/lib64/libjemalloc.so.2
exec quickshell -c helios -d
