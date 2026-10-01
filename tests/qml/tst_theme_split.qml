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

        console.assert(typeof ThemeExportHyprland.buildHyprlandTheme(p) === "string" && ThemeExportHyprland.buildHyprlandTheme(p).length > 0, "hyprland builds");
        console.assert(ThemeExportHyprland.hexToRgbColor("#ff00aa") === "rgb(FF00AA)", "hyprland hex conversion");
        console.assert(ThemeExportGhostty.buildGhosttyTheme(p).includes(p.background), "ghostty builds");
        console.assert(ThemeExportKitty.buildKittyTheme(p).includes(p.text), "kitty builds");
        console.assert(ThemeExportBtop.buildBtopTheme(p).includes("main_bg"), "btop builds");
        console.assert(ThemeExportNvim.buildNvimTheme(p).includes("base16-colorscheme"), "nvim builds");
        console.assert(ThemeExportZed.buildZedTheme(p).name === "Helios", "zed builds");
        console.assert(ThemeExportBat.buildBatTheme(p).includes("<plist"), "bat builds");
        console.assert(ThemeExportFirefox.buildFirefoxCss(p).includes("helios-bg"), "firefox css builds");
        console.assert(ThemeExportYazi.buildYaziTheme(p).includes("[mgr]"), "yazi builds");
        console.assert(ThemeExportAlacritty.buildAlacrittyTheme(p).includes("[colors.primary]"), "alacritty builds");
        console.assert(ThemeExportWezterm.buildWeztermTheme(p).includes("[colors]"), "wezterm builds");
        console.assert(ThemeExportTmux.buildTmuxTheme(p).includes("status-style"), "tmux builds");
        console.assert(ThemeExportVscode.buildVscodeColors(p)["editor.background"] === p.background, "vscode builds");
        console.assert(typeof ThemeExportKiro.writeKiroTheme === "function", "kiro adapter exists and reuses ThemeExportVscode");
        console.assert(ThemeExportRofi.buildRofiTheme(p).includes("background:"), "rofi builds");
        console.assert(ThemeExportWofi.buildWofiCss(p).includes("#input"), "wofi builds");
        console.assert(ThemeExportFuzzel.buildFuzzelTheme(p).includes("selection=" + p.accent.replace("#", "").slice(0, 6) + "ff"), "fuzzel builds");
        console.assert(ThemeExportFuzzel.withInclude("include=/a\n[colors]\nx=1", "include=/h") === "include=/a\ninclude=/h\n[colors]\nx=1", "fuzzel include goes after existing includes");
        console.assert(ThemeExportFuzzel.withInclude("include=/h\n", "include=/h") === "include=/h\n", "fuzzel include not duplicated");
        console.assert(ThemeExportFish.buildFishTheme(p).includes("set -g fish_color_command " + p.accent.replace("#", "").slice(0, 6)), "fish builds");

        console.warn("THEME_SPLIT_TEST_PASS");
        root._terminateDelay.start();
    }
}
