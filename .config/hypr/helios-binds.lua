-- Keybinds for the helios Quickshell config (~/Projects/qml-shell).
-- Kept in its own file so it never touches binds.lua — safe to load even
-- while Noctalia is the active shell; these just no-op if helios isn't running.
--
-- Every `ipc call <target> <function>` below corresponds 1:1 to an
-- IpcHandler in the helios QML tree (shell.qml + modules/*). IPC functions
-- that require an argument (theme apply(name), wallpaper set(path)/
-- folder(path), weather location(text)) aren't bound here — there's no
-- sensible default to hardcode, so drive those from the matching island tab
-- instead. `island appearance(...)`/`liquidGlass(enabled)` are config knobs
-- meant to be set once from the theme tab UI, not toggled from a hotkey.

local mainMod = "SUPER"
local helios = "quickshell -c helios ipc call"

-- Core -----------------------------------------------------------------

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(helios .. " launcher toggle"),
  { description = "Toggle helios launcher" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(helios .. " lock lock"),
  { description = "Lock screen (helios)" })
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd(helios .. " powermenu toggle"),
  { description = "Toggle helios power menu" })
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd(helios .. " keybinds toggle"),
  { description = "Toggle Helios keybind cheatsheet" })

-- OSD / brightness -------------------------------------------------------

-- Volume keys are already bound in binds.lua (wpctl) and need no change here —
-- helios's OSD watches Pipewire directly and pops up on any volume/mute change,
-- regardless of what changed it.

-- Brightness in binds.lua calls brightnessctl directly and won't trigger the
-- helios OSD (it isn't watched passively), so these give a second way to adjust
-- brightness that also shows the OSD, without touching the existing XF86 binds.
hl.bind(mainMod .. " + ALT + Up", hl.dsp.exec_cmd(helios .. " osd brightnessUp"),
  { repeating = true, description = "Raise brightness (helios OSD)" })
hl.bind(mainMod .. " + ALT + Down", hl.dsp.exec_cmd(helios .. " osd brightnessDown"),
  { repeating = true, description = "Lower brightness (helios OSD)" })

-- Island tabs (SUPER + ALT + key opens/toggles that tab; same combo again closes it) --

hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd(helios .. " island toggle clipboard"),
  { description = "Toggle clipboard history island" })
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd(helios .. " island toggle bluetooth"),
  { description = "Toggle bluetooth island" })
hl.bind(mainMod .. " + ALT + N", hl.dsp.exec_cmd(helios .. " island toggle wifi"),
  { description = "Toggle network (wifi) island" })
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd(helios .. " island toggle media"),
  { description = "Toggle media player island" })
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd(helios .. " island toggle weather"),
  { description = "Toggle weather island" })
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd(helios .. " island toggle activity"),
  { description = "Toggle activity island" })
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd(helios .. " island toggle wallpaper"),
  { description = "Toggle wallpaper picker island" })
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd(helios .. " island toggle theme"),
  { description = "Toggle theme picker island" })
hl.bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd(helios .. " island toggle island"),
  { description = "Toggle island settings island" })
hl.bind(mainMod .. " + ALT + ESCAPE", hl.dsp.exec_cmd(helios .. " island close"),
  { description = "Close island panel, whatever tab is open" })

-- Instant actions (SUPER + SHIFT + key fires once, no panel involved) --

hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(helios .. " theme dynamic"),
  { description = "Apply dynamic theme from current wallpaper" })
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(helios .. " clipboard refresh"),
  { description = "Refresh clipboard history" })

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
