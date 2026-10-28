pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "themeExport/system.js" as System
import "themeExport/ghostty.js" as Ghostty
import "themeExport/kitty.js" as Kitty
import "themeExport/btop.js" as Btop
import "themeExport/nvim.js" as Nvim
import "themeExport/zed.js" as Zed
import "themeExport/bat.js" as Bat
import "themeExport/firefox.js" as Firefox
import "themeExport/vivaldi.js" as Vivaldi
import "themeExport/hyprland.js" as Hyprland
import "themeExport/yazi.js" as Yazi
import "themeExport/alacritty.js" as Alacritty
import "themeExport/wezterm.js" as Wezterm
import "themeExport/tmux.js" as Tmux
import "themeExport/vscode.js" as Vscode
import "themeExport/kiro.js" as Kiro
import "themeExport/rofi.js" as Rofi
import "themeExport/wofi.js" as Wofi
import "themeExport/fuzzel.js" as Fuzzel
import "themeExport/fish.js" as Fish

// Themes system and app configs with the shell palette. Each app is a pure
// module in themeExport/: exportTheme(palette, ctx) returns the files to
// write ({ path, text }) and commands to run afterwards to reload the app.
// ctx gives it HOME, read(path) for a config it patches ("" when missing),
// and isDark(hex).
QtObject {
    id: root

    readonly property var apps: ({
        system: System, ghostty: Ghostty, kitty: Kitty, btop: Btop, nvim: Nvim, zed: Zed, bat: Bat,
        firefox: Firefox, vivaldi: Vivaldi, hyprland: Hyprland, yazi: Yazi, alacritty: Alacritty,
        wezterm: Wezterm, tmux: Tmux, vscode: Vscode, kiro: Kiro, rofi: Rofi, wofi: Wofi,
        fuzzel: Fuzzel, fish: Fish
    })

    function context(home, read) {
        return { home: home, read: read, isDark: Themes.isDark };
    }

    // Best-effort per app, so one app's config quirks (missing file,
    // unexpected format) can't stop the others from getting themed.
    function exportAll(palette) {
        const ctx = root.context(Quickshell.env("HOME"), root._read);
        for (const name in root.apps) {
            try {
                const result = root.apps[name].exportTheme(palette, ctx);
                for (const file of result.files) root._write(file.path, file.text);
                for (const command of result.run || []) Quickshell.execDetached(command);
            } catch (e) {
                console.warn("Helios theme: " + name + " failed", e);
            }
        }
    }

    // A fresh FileView per path: a reused one returns the previous file's
    // text when the new path doesn't exist.
    property Component _file: Component {
        FileView { printErrors: false; atomicWrites: true; blockWrites: true; preload: true; blockLoading: true }
    }
    function _read(path) {
        const file = root._file.createObject(root, { path: path });
        const text = file.text() || "";
        file.destroy();
        return text;
    }
    function _write(path, text) {
        const file = root._file.createObject(root, { path: path, preload: false });
        file.setText(text);
        file.destroy();
    }
}
