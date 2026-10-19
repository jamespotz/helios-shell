pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User shortcuts that launch an app (Settings > Custom Commands). The JSON
// state file is the source of truth; ~/.config/hypr/helios-custom-binds.lua
// is generated from it and required by helios-binds.lua, so every change
// rewrites the file and reloads Hyprland.
QtObject {
    id: root

    // [{ mods: ["SUPER", "ALT"], key: "B", app: "firefox", name: "Firefox" }]
    // `app` is a desktop entry id, or one of the `targets` below.
    property var commands: []

    // Apps that follow the system default rather than one fixed app. Browser
    // and file manager resolve through xdg-mime when the key is pressed, so
    // they track Settings > Default Apps; the terminal is Config.terminal.
    readonly property var targets: [
        { id: "default:browser", name: "Default Browser", icon: "public", mime: "x-scheme-handler/https" },
        { id: "default:filemanager", name: "Default File Manager", icon: "folder", mime: "inode/directory" },
        { id: "default:terminal", name: "Default Terminal", icon: "terminal", mime: "" }
    ]

    // Seeded on first run, when there's no state file yet.
    readonly property var defaults: [
        { mods: ["SUPER"], key: "B", app: "default:browser", name: "Default Browser" },
        { mods: ["SUPER"], key: "E", app: "default:filemanager", name: "Default File Manager" },
        { mods: ["SUPER"], key: "T", app: "default:terminal", name: "Default Terminal" }
    ]

    function target(id) { return root.targets.find(t => t.id === id) || null; }

    // Hyprland's modifier order and bitmask (`hyprctl binds -j` modmask).
    readonly property var modifiers: [
        { name: "SUPER", qt: Qt.MetaModifier, bit: 64, label: "Super" },
        { name: "CTRL", qt: Qt.ControlModifier, bit: 4, label: "Ctrl" },
        { name: "ALT", qt: Qt.AltModifier, bit: 8, label: "Alt" },
        { name: "SHIFT", qt: Qt.ShiftModifier, bit: 1, label: "Shift" }
    ]

    readonly property var modifierKeys: [
        Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R,
        Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Shift, Qt.Key_CapsLock
    ]

    // Modifier key -> its Hyprland name, for showing what's held mid-record.
    readonly property var modifierNames: ({
        [Qt.Key_Meta]: "SUPER", [Qt.Key_Super_L]: "SUPER", [Qt.Key_Super_R]: "SUPER",
        [Qt.Key_Control]: "CTRL", [Qt.Key_Alt]: "ALT", [Qt.Key_Shift]: "SHIFT"
    })

    // Qt key -> xkb keysym name, for keys whose name isn't their character.
    readonly property var keysyms: ({
        [Qt.Key_Space]: "SPACE", [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "RETURN",
        [Qt.Key_Tab]: "TAB", [Qt.Key_Backspace]: "BACKSPACE", [Qt.Key_Delete]: "DELETE",
        [Qt.Key_Insert]: "INSERT", [Qt.Key_Home]: "HOME", [Qt.Key_End]: "END",
        [Qt.Key_PageUp]: "PRIOR", [Qt.Key_PageDown]: "NEXT", [Qt.Key_Print]: "PRINT",
        [Qt.Key_Left]: "LEFT", [Qt.Key_Right]: "RIGHT", [Qt.Key_Up]: "UP", [Qt.Key_Down]: "DOWN",
        [Qt.Key_Comma]: "COMMA", [Qt.Key_Period]: "PERIOD", [Qt.Key_Slash]: "SLASH",
        [Qt.Key_Backslash]: "BACKSLASH", [Qt.Key_Semicolon]: "SEMICOLON", [Qt.Key_Apostrophe]: "APOSTROPHE",
        [Qt.Key_Minus]: "MINUS", [Qt.Key_Equal]: "EQUAL", [Qt.Key_BracketLeft]: "BRACKETLEFT",
        [Qt.Key_BracketRight]: "BRACKETRIGHT", [Qt.Key_QuoteLeft]: "GRAVE"
    })

    readonly property var keyLabels: ({
        SPACE: "Space", RETURN: "Return", TAB: "Tab", BACKSPACE: "⌫", DELETE: "Del",
        INSERT: "Ins", HOME: "Home", END: "End", PRIOR: "PgUp", NEXT: "PgDn", PRINT: "PrtSc",
        LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓", COMMA: ",", PERIOD: ".", SLASH: "/",
        BACKSLASH: "\\", SEMICOLON: ";", APOSTROPHE: "'", MINUS: "-", EQUAL: "=",
        BRACKETLEFT: "[", BRACKETRIGHT: "]", GRAVE: "`"
    })

    // A key event as a combo, or null while only modifiers are held or the
    // key has no Hyprland name. Printable keys need a modifier so a typed
    // letter can't become a global shortcut; F-keys may stand alone.
    function comboFromKey(key, qtModifiers) {
        if (root.modifierKeys.includes(key)) return null;
        let name = "";
        if (key >= Qt.Key_A && key <= Qt.Key_Z) name = String.fromCharCode(key);
        else if (key >= Qt.Key_0 && key <= Qt.Key_9) name = String.fromCharCode(key);
        else if (key >= Qt.Key_F1 && key <= Qt.Key_F24) name = "F" + (key - Qt.Key_F1 + 1);
        else name = root.keysyms[key] || "";
        if (!name) return null;
        const mods = root.modifiers.filter(m => (qtModifiers & m.qt) !== 0).map(m => m.name);
        if (mods.length === 0 && !/^F\d+$/.test(name)) return null;
        return { mods: mods, key: name };
    }

    // Modifiers held after a press or release of `key`. A modifier's own
    // press or release isn't always reflected in the event's flags yet.
    function heldModifiers(key, qtModifiers, pressed) {
        const own = root.modifierNames[key];
        return root.modifiers
            .filter(m => m.name === own ? pressed : (qtModifiers & m.qt) !== 0)
            .map(m => m.name);
    }

    function bindString(combo) { return combo.mods.concat([combo.key]).join(" + "); }

    function comboLabels(combo) {
        const mods = combo.mods.map(n => root.modifiers.find(m => m.name === n).label);
        return combo.key ? mods.concat([root.keyLabels[combo.key] || combo.key]) : mods;
    }

    function sameCombo(a, b) {
        return a.key === b.key && a.mods.slice().sort().join() === b.mods.slice().sort().join();
    }

    // Description of the Hyprland bind already on this combo, or "" if free.
    // `binds` is `hyprctl binds -j` output; `exceptIndex` skips one of our
    // own commands (the one being edited), -1 for none. Indices, not object
    // identity: a Repeater's modelData is a copy of the array entry.
    function conflictFor(combo, binds, exceptIndex) {
        const except = root.commands[exceptIndex] || null;
        const own = root.commands.find((c, i) => i !== exceptIndex && root.sameCombo(c, combo));
        if (own) return "Open " + own.name;
        const mask = root.modifiers.filter(m => combo.mods.includes(m.name)).reduce((sum, m) => sum + m.bit, 0);
        const hit = binds.find(b => b.modmask === mask && String(b.key).toUpperCase() === combo.key
            && !(except && b.description === root.describe(except)));
        return hit ? (hit.description || hit.arg || "another shortcut") : "";
    }

    function describe(command) { return "Custom: Open " + command.name; }

    function buildLua(commands) {
        const q = s => JSON.stringify(String(s));
        let out = "-- Generated by Helios (Settings > Custom Commands) — do not edit by hand\n\n"
            + "local is_uwsm = os.getenv('UWSM_FINALIZE_VARNAMES')\n"
            + "-- uwsm-app asks uwsm's app daemon rather than starting Python per launch.\n"
            + "local run_app = is_uwsm and \"uwsm-app -- \" or \"\"\n\n"
            + "-- `entry` is a desktop file id (\"firefox.desktop\") or a shell\n"
            + "-- expression that prints one.\n"
            + "local function launch(entry)\n"
            + "    return is_uwsm and (run_app .. entry) or (\"gtk-launch \" .. entry)\n"
            + "end\n";
        for (const c of commands) {
            const t = root.target(c.app);
            const exec = !t ? "launch(" + q(c.app + ".desktop") + ")"
                : t.mime ? "launch(" + q("\"$(xdg-mime query default " + t.mime + ")\"") + ")"
                : "run_app .. " + q(Config.terminal);
            out += "\nhl.bind(" + q(root.bindString(c)) + ", hl.dsp.exec_cmd(" + exec + "),\n"
                + "  { description = " + q(root.describe(c)) + " })\n";
        }
        return out;
    }

    function add(command) { root._commit(root.commands.concat([command])); }

    function replace(index, command) { root._commit(root.commands.map((c, i) => i === index ? command : c)); }

    function remove(index) { root._commit(root.commands.filter((c, i) => i !== index)); }

    function _commit(next) {
        root.commands = next;
        stateFile.setText(JSON.stringify(next));
        luaFile.setText(root.buildLua(next));
        reloadProc.running = false;
        reloadProc.running = true;
    }

    property FileView stateFile: FileView {
        path: Quickshell.statePath("custom-commands.json")
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(stateFile.text());
                if (Array.isArray(parsed)) root.commands = parsed;
            } catch (e) {
                // Unreadable state — keep the empty list rather than guess.
            }
        }
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) root._commit(root.defaults); }
    }

    property FileView luaFile: FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/helios-custom-binds.lua"
        printErrors: false
        atomicWrites: true
    }

    property Process reloadProc: Process {
        command: ["hyprctl", "reload"]
        onExited: Keybinds.refresh()
    }
}
