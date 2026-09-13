pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ghostty
QtObject {
    id: root

    function buildGhosttyTheme(p) {
        return "palette = 0=" + p.surfaceHigh + "\n"
            + "palette = 1=" + p.danger + "\n"
            + "palette = 2=" + p.success + "\n"
            + "palette = 3=" + p.warning + "\n"
            + "palette = 4=" + p.accent + "\n"
            + "palette = 5=" + p.accent + "\n"
            + "palette = 6=" + p.accent + "\n"
            + "palette = 7=" + p.text + "\n"
            + "palette = 8=" + p.overlay + "\n"
            + "palette = 9=" + p.danger + "\n"
            + "palette = 10=" + p.success + "\n"
            + "palette = 11=" + p.warning + "\n"
            + "palette = 12=" + p.accent + "\n"
            + "palette = 13=" + p.accent + "\n"
            + "palette = 14=" + p.accent + "\n"
            + "palette = 15=" + p.text + "\n"
            + "background = " + p.background + "\n"
            + "foreground = " + p.text + "\n"
            + "cursor-color = " + p.accent + "\n"
            + "cursor-text = " + p.background + "\n"
            + "selection-background = " + p.surfaceHigh + "\n"
            + "selection-foreground = " + p.text + "\n";
    }

    function writeGhosttyTheme(p) {
        const home = Quickshell.env("HOME");
        ghosttyThemeFile.path = home + "/.config/ghostty/themes/helios";
        ghosttyThemeFile.setText(root.buildGhosttyTheme(p));

        ghosttyConfigFile.path = home + "/.config/ghostty/config";
        const existing = ghosttyConfigFile.text();
        const text = /^\s*theme\s*=.*$/m.test(existing)
            ? existing.replace(/^\s*theme\s*=.*$/m, "theme = helios")
            : existing.replace(/\s*$/, "") + "\ntheme = helios\n";
        ghosttyConfigFile.setText(text);
    }

    property FileView ghosttyThemeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView ghosttyConfigFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
}
