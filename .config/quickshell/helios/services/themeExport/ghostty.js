.pragma library

// Ghostty

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

function exportTheme(p, ctx) {
    const config = ctx.read(ctx.home + "/.config/ghostty/config");
    return {
        files: [
            { path: ctx.home + "/.config/ghostty/themes/helios", text: buildGhosttyTheme(p) },
            { path: ctx.home + "/.config/ghostty/config", text: /^\s*theme\s*=.*$/m.test(config)
                ? config.replace(/^\s*theme\s*=.*$/m, "theme = helios")
                : config.replace(/\s*$/, "") + "\ntheme = helios\n" }
        ]
    };
}
