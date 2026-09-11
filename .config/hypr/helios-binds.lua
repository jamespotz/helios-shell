-- Keybinds for the helios Quickshell config (~/Projects/qml-shell).
-- Kept in its own file so it never touches binds.lua — safe to load even
-- while Noctalia is the active shell; these just no-op if helios isn't running.
--
-- Every `ipc call <target> <function>` below corresponds 1:1 to an
-- IpcHandler in the helios QML tree (shell.qml + modules/*). IPC functions
-- that require an argument (theme apply(name), wallpaper set(path)/
-- folder(path), weather location(text), recorder mode(name)) aren't bound
-- here — there's no sensible default to hardcode, so drive those from the matching island tab
-- instead. `island appearance(...)`/`liquidGlass(enabled)` are config knobs
-- meant to be set once from the theme tab UI, not toggled from a hotkey.

local mainMod = "SUPER"
local helios = "quickshell -c helios ipc call"

-- Core -----------------------------------------------------------------

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(helios .. " launcher toggle"),
  { description = "helios: Toggle launcher" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(helios .. " lock lock"),
  { description = "helios: Lock screen" })
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd(helios .. " powermenu toggle"),
  { description = "helios: Toggle power menu" })
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd(helios .. " keybinds toggle"),
  { description = "helios: Toggle keybind cheatsheet" })
hl.bind(mainMod .. " + COMMA", hl.dsp.exec_cmd(helios .. " settings toggle \"\""),
  { description = "helios: Toggle settings window" })

-- OSD / brightness -------------------------------------------------------

-- Volume keys are already bound in binds.lua (wpctl) and need no change here —
-- helios's OSD watches Pipewire directly and pops up on any volume/mute change,
-- regardless of what changed it.

-- Brightness in binds.lua calls brightnessctl directly and won't trigger the
-- helios OSD (it isn't watched passively), so these give a second way to adjust
-- brightness that also shows the OSD, without touching the existing XF86 binds.
hl.bind(mainMod .. " + ALT + Up", hl.dsp.exec_cmd(helios .. " osd brightnessUp"),
  { repeating = true, description = "helios: Raise brightness with OSD" })
hl.bind(mainMod .. " + ALT + Down", hl.dsp.exec_cmd(helios .. " osd brightnessDown"),
  { repeating = true, description = "helios: Lower brightness with OSD" })

-- Island tabs (SUPER + ALT + key opens/toggles that tab; same combo again closes it) --

hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd(helios .. " island toggle clipboard"),
  { description = "helios: Toggle clipboard history island" })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(helios .. " island toggle bluetooth"),
  { description = "helios: Toggle bluetooth island" })
hl.bind(mainMod .. " + ALT + N", hl.dsp.exec_cmd(helios .. " island toggle wifi"),
  { description = "helios: Toggle network (wifi) island" })
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd(helios .. " island toggle media"),
  { description = "helios: Toggle media player island" })
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd(helios .. " island toggle weather"),
  { description = "helios: Toggle weather island" })
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd(helios .. " island toggle wallpaper"),
  { description = "helios: Toggle wallpaper picker island" })
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd(helios .. " island toggle theme"),
  { description = "helios: Toggle theme picker island" })
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(helios .. " island toggle recorder"),
  { description = "helios: Toggle screen recorder island" })
hl.bind(mainMod .. " + ALT + ESCAPE", hl.dsp.exec_cmd(helios .. " island close"),
  { description = "helios: Close island panel, whatever tab is open" })

-- Instant actions (SUPER + SHIFT + key fires once, no panel involved) --

hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(helios .. " theme dynamic"),
  { description = "helios: Apply dynamic theme from current wallpaper" })
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(helios .. " clipboard refresh"),
  { description = "helios: Refresh clipboard history" })
-- Own `clipboard toggle` ipc (vs. the `island toggle clipboard` bind above) so
-- this keeps working even if the clipboard tab's island target ever changes.
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(helios .. " clipboard toggle"),
  { description = "helios: Toggle clipboard history island" })

-- Screen recorder: start/stop against whatever capture mode (Full Screen /
-- Window-App / Custom Area) is currently selected in the recorder tab,
-- without needing to open the island first.
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(helios .. " recorder toggle"),
  { description = "helios: Start/stop screen recording" })


-- Reload / relaunch (SUPER + SHIFT + R) --------------------------------

-- Goes through a script, not `ipc call` — IPC only works while helios is
-- already running and responsive, which isn't a given after a crash or a
-- change that needs a fresh process (most QML edits hot-reload on save;
-- this is for when that's not enough or the shell isn't running at all).
-- helios-reload.sh, not an inline `cmd1; cmd2` here: the semicolon-chained
-- version never fired on this fork — config-load-time bind marshalling
-- didn't run it, even though the identical string worked fine run directly
-- or via a live `hyprctl dispatch`.
hl.bind(mainMod .. " + SHIFT + R",
  hl.dsp.exec_cmd("sh ~/.config/hypr/helios-reload.sh"),
  { description = "Reload/relaunch helios" })


-- System update (SUPER + SHIFT + U) -------------------------------------

-- Runs topgrade in a terminal (sudo needs a real tty to prompt on) and
-- reports progress through the "task" IPC target, same as the
-- `quickshell ipc call task ...` example in shell.qml, so the Island shows
-- live progress alongside the terminal output. A separate Ghostty instance
-- makes Hyprland focus the update window instead of opening a hidden tab in an
-- existing Ghostty window. --wait-after-command keeps errors visible.
hl.bind(mainMod .. " + SHIFT + U",
  hl.dsp.exec_cmd("ghostty --gtk-single-instance=false --wait-after-command=true -e sh ~/.config/hypr/helios-topgrade.sh"),
  { description = "Run topgrade with Island progress" })


-- Screenshot (SUPER + SHIFT + S for region, SUPER + Print for fullscreen, SUPER + ALT + S for window)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(helios .. " screenshot region"),
  { description = "helios: Screenshot region" })
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(helios .. " screenshot full"),
  { description = "helios: Screenshot fullscreen" })
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd(helios .. " screenshot window"),
  { description = "helios: Screenshot active window" })
hl.bind(mainMod .. " + ALT + O", hl.dsp.exec_cmd(helios .. " screenshot ocr"),
  { description = "helios: OCR screen region to clipboard" })
-- Own `screenshot toggle` ipc: opens the screenshot island tab itself,
-- unlike the region/full/window/ocr binds above which fire a capture
-- immediately without showing any panel.
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(helios .. " screenshot toggle"),
  { description = "helios: Toggle screenshot island" })

-- Night light / Do Not Disturb / Caffeine toggles
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(helios .. " nightlight toggle"),
  { description = "helios: Toggle night light" })
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(helios .. " dnd toggle"),
  { description = "helios: Toggle Do Not Disturb" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(helios .. " idle caffeine"),
  { description = "helios: Toggle caffeine mode" })

-- New island tabs
hl.bind(mainMod .. " + ALT + D", hl.dsp.exec_cmd(helios .. " island toggle display"),
  { description = "helios: Toggle display settings island" })
hl.bind(mainMod .. " + ALT + H", hl.dsp.exec_cmd(helios .. " island toggle notifications"),
  { description = "helios: Toggle notification history island" })
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd(helios .. " island toggle nightlight"),
  { description = "helios: Toggle night light island" })
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd(helios .. " island toggle idlelock"),
  { description = "helios: Toggle idle/lock settings island" })
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd(helios .. " island toggle volume"),
  { description = "helios: Toggle audio output/input island" })
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd(helios .. " island toggle power"),
  { description = "helios: Toggle power profile island" })
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd(helios .. " island toggle calendar"),
  { description = "helios: Toggle calendar island" })
-- Own `automation toggle` ipc (see shell.qml) rather than `island toggle
-- automation` directly, same reasoning as the systemmonitor bind below.
hl.bind(mainMod .. " + ALT + U", hl.dsp.exec_cmd(helios .. " automation toggle"),
  { description = "helios: Toggle device automation rules island" })

-- System monitor: own ipc target (see systemmonitor toggle in shell.qml),
-- bound to the literal Ctrl+Alt+Delete chord rather than the mainMod
-- convention above, since that's the muscle-memory shortcut for "show me
-- what's using my system" on every other desktop.
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd(helios .. " systemmonitor toggle"),
  { description = "helios: Toggle system monitor island (Ctrl+Alt+Del)" })
