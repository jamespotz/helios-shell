import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    // The seed lands on FileView's async loadFailed, after creation.
    readonly property Timer seedDelay: Timer { interval: 200; onTriggered: root.run() }

    Component.onCompleted: {
        CustomCommands.commands;
        root.seedDelay.start();
    }

    function run() {
        try {
            const seeded = JSON.stringify(CustomCommands.commands);
            CustomCommands.commands = [];
            const superAlt = Qt.MetaModifier | Qt.AltModifier;

            // Holding only modifiers waits for the real key.
            root.verify(CustomCommands.comboFromKey(Qt.Key_Meta, Qt.MetaModifier) === null, "modifier alone");
            // A bare letter would steal typing; an F-key alone is fine.
            root.verify(CustomCommands.comboFromKey(Qt.Key_B, 0) === null, "bare letter rejected");
            root.verify(CustomCommands.bindString(CustomCommands.comboFromKey(Qt.Key_F5, 0)) === "F5", "bare F-key");

            const combo = CustomCommands.comboFromKey(Qt.Key_B, superAlt);
            root.verify(CustomCommands.bindString(combo) === "SUPER + ALT + B", "super+alt+b: " + CustomCommands.bindString(combo));
            root.verify(CustomCommands.comboLabels(combo).join(" ") === "Super Alt B", "labels");
            root.verify(CustomCommands.bindString(CustomCommands.comboFromKey(Qt.Key_Space, Qt.ControlModifier)) === "CTRL + SPACE", "named key");

            // Conflicts with an existing Hyprland bind (modmask 72 = SUPER|ALT).
            const binds = [{ modmask: 72, key: "B", description: "helios: Toggle idle/lock settings island" }];
            root.verify(CustomCommands.conflictFor(combo, binds, -1) === "helios: Toggle idle/lock settings island", "conflict found");
            root.verify(CustomCommands.conflictFor(CustomCommands.comboFromKey(Qt.Key_B, Qt.MetaModifier), binds, -1) === "", "super+b free");

            // Editing a command must not conflict with itself (matched by
            // index, since a Repeater's modelData is a copy of the entry).
            CustomCommands.commands = [{ mods: ["SUPER"], key: "E", app: "org.gnome.Nautilus", name: "Files" }];
            const superE = CustomCommands.comboFromKey(Qt.Key_E, Qt.MetaModifier);
            const own = [{ modmask: 64, key: "E", description: "Custom: Open Files" }];
            root.verify(CustomCommands.conflictFor(superE, own, -1) === "Open Files", "new command conflicts with existing");
            root.verify(CustomCommands.conflictFor(superE, own, 0) === "", "edited command ignores itself");
            CustomCommands.commands = [];

            // First run (no state file) seeds the three default commands.
            root.verify(seeded === JSON.stringify(CustomCommands.defaults), "seeded defaults: " + seeded);
            const defaultsLua = CustomCommands.buildLua(CustomCommands.defaults);
            root.verify(defaultsLua.includes('hl.bind("SUPER + B", hl.dsp.exec_cmd(launch("\\"$(xdg-mime query default x-scheme-handler/https)\\"")),'),
                "default browser:\n" + defaultsLua);
            root.verify(defaultsLua.includes('hl.bind("SUPER + E", hl.dsp.exec_cmd(launch("\\"$(xdg-mime query default inode/directory)\\"")),'),
                "default file manager");
            root.verify(defaultsLua.includes('hl.bind("SUPER + T", hl.dsp.exec_cmd(run_app .. "' + Config.terminal + '"),'),
                "default terminal");

            const lua = CustomCommands.buildLua([{ mods: ["SUPER"], key: "B", app: "firefox", name: "Firefox" }]);
            root.verify(lua.includes('hl.bind("SUPER + B", hl.dsp.exec_cmd(launch("firefox.desktop")),'), "lua bind:\n" + lua);
            root.verify(lua.includes('description = "Custom: Open Firefox"'), "lua description");
            console.warn("CUSTOM_COMMANDS_TEST_PASS");
        } catch (error) {
            console.error("CUSTOM_COMMANDS_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
