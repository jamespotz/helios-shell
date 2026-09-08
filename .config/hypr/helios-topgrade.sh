#!/bin/sh
# Runs topgrade and reports progress to the Island via the "task" IPC target
# (see Tasks.qml). topgrade has no percentage output, so progress stays
# indeterminate (-1) and the label tracks whichever step is currently
# running, parsed from its "―― HH:MM:SS - <Step> ――" section headers.
ipc="quickshell -c helios ipc call task"
$ipc start topgrade "Updating system…"

# Runs in a terminal (see helios-binds.lua) so sudo gets a real tty to
# prompt on — a GUI askpass dialog (zenity) never mapped a window under
# this Hyprland fork when launched from a bare keybind exec.
exit_file=$(mktemp)
{ topgrade -y 2>&1; echo $? > "$exit_file"; } | while IFS= read -r line; do
    printf '%s\n' "$line"
    step=$(printf '%s' "$line" | sed -n 's/^―― [0-9:]* - \(.*\) ――$/\1/p')
    [ -n "$step" ] && $ipc progress topgrade -1 "$step"
done

ok=false
[ "$(cat "$exit_file")" = "0" ] && ok=true
rm -f "$exit_file"
$ipc done topgrade $ok
