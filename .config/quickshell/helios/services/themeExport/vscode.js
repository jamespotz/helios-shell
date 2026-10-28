.pragma library
.import "jsonc.js" as Jsonc

// VS Code
//
// settings.json is JSONC — same surgical-patch approach as
// zed.js's mergeZedSettings, only replacing the
// "workbench.colorCustomizations" key so the rest of the user's settings
// survive untouched.

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
    return Jsonc.setProperty(existing || "{\n}\n", "workbench.colorCustomizations", JSON.stringify(colors, null, 4));
}

function exportTheme(p, ctx) {
    const path = ctx.home + "/.config/Code/User/settings.json";
    return { files: [{ path: path, text: mergeVscodeSettings(ctx.read(path), buildVscodeColors(p)) }] };
}
