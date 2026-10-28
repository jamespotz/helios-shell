import QtQuick
import Quickshell
import Quickshell.Io
import services

// Renders every app's theme export for a fixed palette and seeded configs
// into $HELIOS_THEME_OUT/<app>.txt; run-theme-export-test.sh compares them
// with tests/fixtures/theme-export.
ShellRoot {
    id: root
    readonly property Process terminator: Process { command: ["sh", "-c", 'kill -TERM "$PPID"'] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    readonly property string home: "/home/test"
    // Existing configs the exporters patch; anything else reads as missing.
    readonly property var seeds: ({
        "/.config/kitty/kitty.conf": "font_size 12\n",
        "/.config/alacritty/alacritty.toml": "[general]\nlive_config_reload = true\n",
        "/.config/btop/btop.conf": "color_theme = \"Default\"\nupdate_ms = 2000\n",
        "/.config/ghostty/config": "font-size = 12\ntheme = old\n",
        "/.config/rofi/config.rasi": "configuration {}\n",
        "/.config/tmux/tmux.conf": "set -g mouse on\n",
        "/.config/wofi/style.css": "window { margin: 4px; }\n",
        "/.config/fuzzel/fuzzel.ini": "[main]\nfont=Inter\n[colors]\nbackground=000000ff\n",
        "/.config/bat/config": "--style=plain\n--theme=\"Old\"\n",
        "/.config/wezterm/wezterm.lua": "local wezterm = require \"wezterm\"\nlocal config = wezterm.config_builder()\nreturn config\n",
        "/.config/Code/User/settings.json": "{\n  // keep\n  \"editor.fontSize\": 14\n}\n",
        "/.config/zed/settings.json": "{\n  \"theme\": {\"mode\": \"system\", \"light\": \"One Light\"}\n}\n",
        "/.mozilla/firefox/profiles.ini": "[Install4F96D1932A9F858E]\nDefault=abc.default\n",
        "/.mozilla/firefox/abc.default/user.js": "user_pref(\"a\", 1);\n",
        "/.config/vivaldi/Last Version": "7.0\n",
        "/.config/kdeglobals": "[General]\nfont=Inter\n[KDE]\nSingleClick=false\n"
    })
    function read(path) { return root.seeds[path.slice(root.home.length)] || ""; }

    property FileView out: FileView { printErrors: false; blockWrites: true }

    Component.onCompleted: {
        try {
            const p = Themes.deriveFullPalette(Themes.presets.helios);
            const ctx = ThemeExport.context(root.home, root.read);
            for (const name in ThemeExport.apps) {
                const result = ThemeExport.apps[name].exportTheme(p, ctx);
                let text = "";
                for (const file of result.files) text += "=== " + file.path + "\n" + file.text + "\n";
                for (const command of result.run || []) text += "=== run " + command.join(" ") + "\n";
                root.out.path = Quickshell.env("HELIOS_THEME_OUT") + "/" + name + ".txt";
                root.out.setText(text);
            }
            const fuzzel = ThemeExport.apps.fuzzel;
            if (fuzzel.withInclude("include=/a\n[colors]\nx=1", "include=/h") !== "include=/a\ninclude=/h\n[colors]\nx=1")
                throw new Error("fuzzel include goes after existing includes");
            if (fuzzel.withInclude("include=/h\n", "include=/h") !== "include=/h\n") throw new Error("fuzzel include duplicated");
            const vscode = JSON.parse(ThemeExport.apps.vscode.mergeVscodeSettings('{"workbench.colorCustomizations":{"[Dark]":{"old":true}},"keep":true}', {fresh:true}));
            if (!vscode.keep || !vscode["workbench.colorCustomizations"].fresh) throw new Error("VS Code merge");
            const zed = JSON.parse(ThemeExport.apps.zed.mergeZedSettings('{"theme":{}}', true));
            if (zed.theme.mode !== "dark" || zed.theme.dark !== "Helios") throw new Error("Zed merge");
            if (ThemeExport.apps.firefox.exportTheme(p, ThemeExport.context(root.home, () => "")).files.length !== 0)
                throw new Error("Firefox without a profile writes nothing");
            if (ThemeExport.apps.vivaldi.exportTheme(p, ThemeExport.context(root.home, () => "")).files.length !== 0)
                throw new Error("Vivaldi that never ran writes nothing");
            console.warn("THEME_EXPORT_TEST_PASS");
        } catch (error) {
            console.warn("THEME_EXPORT_TEST_FAIL", error);
        }
        root.terminateDelay.start();
    }
}
