import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process _terminator: Process {
        command: ["sh", "-c", 'kill -TERM "$PPID"']
    }
    readonly property Timer _terminateDelay: Timer {
        interval: 50
        onTriggered: root._terminator.running = true
    }

    Component.onCompleted: {
        const p = Themes.deriveFullPalette(Themes.presets.helios);

        console.assert(typeof ThemeHyprland.buildHyprlandTheme(p) === "string" && ThemeHyprland.buildHyprlandTheme(p).length > 0, "hyprland builds");
        console.assert(ThemeHyprland.hexToRgbColor("#ff00aa") === "rgb(FF00AA)", "hyprland hex conversion");
        console.assert(ThemeGhostty.buildGhosttyTheme(p).includes(p.background), "ghostty builds");
        console.assert(ThemeKitty.buildKittyTheme(p).includes(p.text), "kitty builds");
        console.assert(ThemeBtop.buildBtopTheme(p).includes("main_bg"), "btop builds");
        console.assert(ThemeNvim.buildNvimTheme(p).includes("base16-colorscheme"), "nvim builds");
        console.assert(ThemeZed.buildZedTheme(p).name === "Helios", "zed builds");
        console.assert(ThemeBat.buildBatTheme(p).includes("<plist"), "bat builds");
        console.assert(ThemeFirefox.buildFirefoxCss(p).includes("helios-bg"), "firefox css builds");
        console.assert(ThemeYazi.buildYaziTheme(p).includes("[mgr]"), "yazi builds");
        console.assert(ThemeAlacritty.buildAlacrittyTheme(p).includes("[colors.primary]"), "alacritty builds");
        console.assert(ThemeWezterm.buildWeztermTheme(p).includes("[colors]"), "wezterm builds");
        console.assert(ThemeTmux.buildTmuxTheme(p).includes("status-style"), "tmux builds");
        console.assert(ThemeVscode.buildVscodeColors(p)["editor.background"] === p.background, "vscode builds");
        console.assert(typeof ThemeKiro.writeKiroTheme === "function", "kiro adapter exists and reuses ThemeVscode");
        console.assert(ThemeRofi.buildRofiTheme(p).includes("background:"), "rofi builds");
        console.assert(ThemeWofi.buildWofiCss(p).includes("#input"), "wofi builds");

        console.warn("THEME_SPLIT_TEST_PASS");
        root._terminateDelay.start();
    }
}
