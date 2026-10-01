pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// VS Code
//
// settings.json is JSONC — same surgical-patch approach as
// Themes.qml's mergeZedSettings, only replacing the
// "workbench.colorCustomizations" key so the rest of the user's settings
// survive untouched.
QtObject {
    id: root

    function buildVscodeColors(p) {
        return {
            "editor.background": p.background,
            "editor.foreground": p.text,
            "editorCursor.foreground": p.accent,
            "editor.selectionBackground": p.surfaceHigh,
            "editor.lineHighlightBackground": p.surface,
            "sideBar.background": p.surface,
            "sideBar.foreground": p.text,
            "activityBar.background": p.surface,
            "activityBar.foreground": p.text,
            "statusBar.background": p.surface,
            "statusBar.foreground": p.text,
            "titleBar.activeBackground": p.surface,
            "titleBar.activeForeground": p.text,
            "tab.activeBackground": p.background,
            "tab.inactiveBackground": p.surface,
            "focusBorder": p.accent,
            "button.background": p.accent,
            "button.foreground": p.accentText,
            "badge.background": p.accent,
            "badge.foreground": p.accentText,
            "terminal.background": p.background,
            "terminal.foreground": p.text,
            "terminal.ansiRed": p.danger,
            "terminal.ansiGreen": p.success,
            "terminal.ansiYellow": p.warning,
            "terminal.ansiBlue": p.accent,
            "terminal.ansiMagenta": p.accent,
            "terminal.ansiCyan": p.accent
        };
    }

    function mergeVscodeSettings(existing, colors) {
        const text = existing || "{\n}\n";
        const body = JSON.stringify(colors, null, 4).replace(/^{\n|\n}$/g, "").split("\n").join("\n    ");
        const block = "\"workbench.colorCustomizations\": {\n    " + body.trim() + "\n  }";
        if (!/"workbench\.colorCustomizations"\s*:\s*\{/.test(text)) {
            return text.replace(/\{/, "{\n  " + block + ",");
        }
        return text.replace(/"workbench\.colorCustomizations"\s*:\s*\{[\s\S]*?\n\s*\}/, block);
    }

    function writeVscodeTheme(p) {
        vscodeSettingsFile.path = Quickshell.env("HOME") + "/.config/Code/User/settings.json";
        vscodeSettingsFile.setText(root.mergeVscodeSettings(vscodeSettingsFile.text(), root.buildVscodeColors(p)));
    }

    property FileView vscodeSettingsFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
}
