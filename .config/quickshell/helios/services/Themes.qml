pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Theme presets + persistence + system app theming (GTK/KDE, Ghostty, Kitty,
// btop, Neovim, Zed, Bat, Yazi, best-effort Firefox), and dynamic theme
// generation from the current wallpaper via matugen. Colors.qml holds the
// live palette the shell UI binds to; this singleton owns picking one and
// pushing it in.
QtObject {
    id: root

    // Loaded from data/themes.json (see themesDataFile below). The single
    // helios entry here is only a safety net if that file is missing/corrupt.
    property var presets: ({
        helios: {
            label: "Helios", background: "#14121a", surface: "#282331", surfaceHigh: "#3a3342",
            overlay: "#6f6580", text: "#eae6f0", subtext: "#b3a9c4", accent: "#f0a868",
            accentText: "#2c1c0f", danger: "#e5707e", warning: "#eec172", success: "#8fd08a"
        }
    })

    property var presetOrder: ["helios"]

    property FileView themesDataFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/helios/data/themes.json"
        printErrors: false
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(themesDataFile.text());
                if (parsed && parsed.presets && Array.isArray(parsed.order)) {
                    root.presets = parsed.presets;
                    root.presetOrder = parsed.order;
                }
            } catch (e) {
                // Missing/corrupt data file — falls back to the built-in helios preset above.
            }
            root.restoreFromSettings();
        }
    }

    // Matugen scheme variants selectable for dynamic (wallpaper-driven)
    // mode. `swatch` is a small set of fixed representative colors (not
    // generated from the current wallpaper — that would mean spawning
    // matugen once per scheme just to render a settings panel) used purely
    // as a visual hint of each scheme's character.
    readonly property var schemeOptions: [
        { label: "Tonal Spot", value: "scheme-tonal-spot", swatch: ["#8e7cc3"] },
        { label: "Vibrant", value: "scheme-vibrant", swatch: ["#ff2f92"] },
        { label: "Expressive", value: "scheme-expressive", swatch: ["#ff7a00"] },
        { label: "Fruit Salad", value: "scheme-fruit-salad", swatch: ["#ff6f61", "#ffd23f", "#4fd8a0"] },
        { label: "Rainbow", value: "scheme-rainbow", swatch: ["#ff5252", "#5bd65b", "#5b9dff"] },
        { label: "Content", value: "scheme-content", swatch: ["#4f86c6"] },
        { label: "Fidelity", value: "scheme-fidelity", swatch: ["#3f7d5c"] },
        { label: "Monochrome", value: "scheme-monochrome", swatch: ["#9a9a9a"] },
        { label: "Neutral", value: "scheme-neutral", swatch: ["#a89f91"] }
    ]

    readonly property string mode: settingsAdapter.mode
    readonly property string presetName: settingsAdapter.presetName
    readonly property string paletteScheme: settingsAdapter.paletteScheme
    readonly property bool dynamicDark: settingsAdapter.dynamicDark
    property bool generating: false
    property string lastError: ""

    function currentLabel() {
        if (root.mode === "dynamic") return "Dynamic (wallpaper)";
        const p = root.presets[root.presetName];
        return p ? p.label : root.presetName;
    }

    function applyPreset(name) {
        const palette = root.presets[name];
        if (!palette) return;
        settingsAdapter.mode = "preset";
        settingsAdapter.presetName = name;
        root.settingsFile.writeAdapter();
        const full = root.deriveFullPalette(palette);
        Colors.apply(full);
        root.writeSystemTheme(full);
    }

    // Entry point for "regenerate the dynamic theme" — called from the
    // Dynamic button, the wallpaper service on path change, and the scheme
    // picker. Debounced via regenerateTimer rather than spawning matugen
    // immediately so a burst of calls (rapid wallpaper switching, mashing
    // scheme chips) collapses into a single process.
    function applyDynamic() {
        if (!Wallpaper.path) { root.lastError = "Set a wallpaper first"; return; }
        if (Wallpaper.isVideo) { return; }
        root.lastError = "";
        root.generating = true;
        root.regenerateTimer.restart();
    }

    property Timer regenerateTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: root.runMatugen()
    }

    function runMatugen() {
        if (!Wallpaper.path) { root.generating = false; return; }
        let img = Wallpaper.path;
        if (img.startsWith("~")) img = Quickshell.env("HOME") + img.slice(1);
        // -j/--dry-run returns both light and dark for every role in one
        // call regardless of -m, so a single run covers both variants —
        // no -m flag needed, and toggling dark/light later is free.
        matugenProc.command = ["matugen", "image", img, "-t", root.paletteScheme, "-j", "hex", "--dry-run", "--prefer", "saturation"];
        matugenProc.running = false;
        matugenProc.running = true;
    }

    // Changes which scheme matugen renders. Only triggers a regeneration
    // while dynamic mode is actually active/visible — picking a scheme
    // while a static preset is showing just changes what "Dynamic" will
    // use next time, without an invisible regenerate happening behind it.
    function setPaletteScheme(name) {
        if (settingsAdapter.paletteScheme === name) return;
        settingsAdapter.paletteScheme = name;
        root.settingsFile.writeAdapter();
        if (root.mode === "dynamic") root.applyDynamic();
    }

    // Switches the active dynamic-mode variant. Both light and dark are
    // cached from the last successful matugen run, so this is normally a
    // free, instant swap with no process spawn — matugen only re-runs if no
    // valid cache exists yet for the requested variant.
    function setDynamicMode(isDark) {
        if (settingsAdapter.dynamicDark === isDark) return;
        settingsAdapter.dynamicDark = isDark;
        root.settingsFile.writeAdapter();
        if (root.mode !== "dynamic") return;
        const cached = isDark ? settingsAdapter.dynamicPaletteDark : settingsAdapter.dynamicPaletteLight;
        if (cached) {
            try {
                const palette = JSON.parse(cached);
                Colors.apply(palette);
                root.writeSystemTheme(palette);
                return;
            } catch (e) { /* fall through to a real regenerate */ }
        }
        root.applyDynamic();
    }

    function toHex(c) {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    // Shifts a color's hue while keeping its saturation/lightness, so
    // warning/success read as "harmonized" with the wallpaper's mood instead
    // of a jarring stock amber/green (there's no material-you role for either).
    function harmonize(hex, hueDeg) {
        const c = Qt.color(hex);
        const shifted = Qt.hsla(hueDeg / 360, Math.max(c.hslSaturation, 0.4), Math.max(Math.min(c.hslLightness, 0.75), 0.45), 1.0);
        return root.toHex(shifted);
    }

    function hueOf(hex) {
        return Qt.color(hex).hslHue * 360;
    }

    // Builds the full legacy + Material-role palette for one variant
    // ("light" or "dark") out of a single matugen JSON response.
    function buildPaletteFromMatugen(colors, variant) {
        const pick = k => colors[k][variant].color;
        const primary = pick("primary");
        return {
            label: "Dynamic",
            background: pick("background"),
            surface: pick("surface_container"),
            surfaceHigh: pick("surface_container_high"),
            overlay: pick("outline"),
            text: pick("on_surface"),
            subtext: pick("on_surface_variant"),
            accent: primary,
            accentText: pick("on_primary"),
            danger: pick("error"),
            warning: root.harmonize(primary, 45),
            success: root.harmonize(primary, 140),

            backgroundText: pick("on_background"),
            surfaceText: pick("on_surface"),
            surfaceVariant: pick("surface_variant"),
            surfaceVariantText: pick("on_surface_variant"),
            surfaceContainer: pick("surface_container"),
            surfaceContainerLow: pick("surface_container_low"),
            surfaceContainerHigh: pick("surface_container_high"),

            primary: primary,
            primaryText: pick("on_primary"),
            primaryContainer: pick("primary_container"),
            primaryContainerText: pick("on_primary_container"),

            secondary: pick("secondary"),
            secondaryText: pick("on_secondary"),
            secondaryContainer: pick("secondary_container"),
            secondaryContainerText: pick("on_secondary_container"),

            tertiary: pick("tertiary"),
            tertiaryText: pick("on_tertiary"),
            tertiaryContainer: pick("tertiary_container"),
            tertiaryContainerText: pick("on_tertiary_container"),

            error: pick("error"),
            errorText: pick("on_error"),
            outline: pick("outline"),
            shadow: pick("shadow")
        };
    }

    // Fills in the Material-role keys for a legacy 11-key preset palette,
    // deterministically, so static presets expose the same full API dynamic
    // (matugen) palettes do. Presets don't model a container/on-container
    // contrast distinction, so *Container roles collapse to their base
    // role's own color. secondary/tertiary are derived by hue-shifting the
    // preset's accent (same harmonize() trick used for warning/success)
    // rather than inventing new preset data.
    function deriveFullPalette(base) {
        const accentHue = root.hueOf(base.accent);
        const secondaryHex = root.harmonize(base.accent, (accentHue + 40) % 360);
        const tertiaryHex = root.harmonize(base.accent, (accentHue + 200) % 360);
        return {
            label: base.label,
            background: base.background,
            surface: base.surface,
            surfaceHigh: base.surfaceHigh,
            overlay: base.overlay,
            text: base.text,
            subtext: base.subtext,
            accent: base.accent,
            accentText: base.accentText,
            danger: base.danger,
            warning: base.warning,
            success: base.success,

            backgroundText: base.text,
            surfaceText: base.text,
            surfaceVariant: base.surfaceHigh,
            surfaceVariantText: base.subtext,
            surfaceContainer: base.surface,
            surfaceContainerLow: base.background,
            surfaceContainerHigh: base.surfaceHigh,

            primary: base.accent,
            primaryText: base.accentText,
            primaryContainer: base.accent,
            primaryContainerText: base.accentText,

            secondary: secondaryHex,
            secondaryText: base.accentText,
            secondaryContainer: secondaryHex,
            secondaryContainerText: base.accentText,

            tertiary: tertiaryHex,
            tertiaryText: base.accentText,
            tertiaryContainer: tertiaryHex,
            tertiaryContainerText: base.accentText,

            error: base.danger,
            errorText: base.accentText,
            outline: base.overlay,
            shadow: "#000000"
        };
    }

    property Process matugenProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.generating = false;
                try {
                    const data = JSON.parse(text);
                    const colors = data.colors;
                    const paletteDark = root.buildPaletteFromMatugen(colors, "dark");
                    const paletteLight = root.buildPaletteFromMatugen(colors, "light");
                    settingsAdapter.mode = "dynamic";
                    settingsAdapter.dynamicPaletteDark = JSON.stringify(paletteDark);
                    settingsAdapter.dynamicPaletteLight = JSON.stringify(paletteLight);
                    root.settingsFile.writeAdapter();
                    const active = root.dynamicDark ? paletteDark : paletteLight;
                    Colors.apply(active);
                    root.writeSystemTheme(active);
                } catch (e) {
                    root.lastError = "Failed to read matugen output";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim().length > 0) root.lastError = text.trim(); }
        }
        // Safety net: if matugen fails to even start (not on PATH, etc.) the
        // stdout collector never fires, so "Generating…" would otherwise stick.
        onExited: (exitCode) => {
            root.generating = false;
            if (exitCode !== 0 && root.lastError === "") root.lastError = "matugen exited with code " + exitCode + " — is it installed?";
        }
    }

    // --- System app theming (GTK + KDE/Qt) ---------------------------------

    property var pendingPalette: null

    function writeSystemTheme(palette) {
        root.pendingPalette = palette;
        mkdirProc.running = false;
        mkdirProc.running = true;
    }

    property Process mkdirProc: Process {
        command: ["mkdir", "-p",
            Quickshell.env("HOME") + "/.config/gtk-3.0",
            Quickshell.env("HOME") + "/.config/gtk-4.0",
            Quickshell.env("HOME") + "/.local/share/color-schemes",
            Quickshell.env("HOME") + "/.config/ghostty/themes",
            Quickshell.env("HOME") + "/.config/kitty/themes",
            Quickshell.env("HOME") + "/.config/btop/themes",
            Quickshell.env("HOME") + "/.config/nvim/lua",
            Quickshell.env("HOME") + "/.config/zed/themes",
            Quickshell.env("HOME") + "/.config/bat/themes",
            Quickshell.env("HOME") + "/.config/yazi",
            Quickshell.env("HOME") + "/.config/alacritty/themes",
            Quickshell.env("HOME") + "/.config/wezterm/colors",
            Quickshell.env("HOME") + "/.config/tmux",
            Quickshell.env("HOME") + "/.config/Code/User",
            Quickshell.env("HOME") + "/.config/Kiro/User",
            Quickshell.env("HOME") + "/.config/rofi",
            Quickshell.env("HOME") + "/.config/wofi"]
        onExited: root.writeSystemThemeFiles()
    }

    function rgb(hex) {
        const c = Qt.color(hex);
        return Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255);
    }

    function isDark(hex) { return Qt.color(hex).hslLightness < 0.5; }

    function buildGtkCss(p) {
        return "/* Generated by Helios (Themes.qml) — do not edit by hand */\n"
            + "@define-color theme_bg_color " + p.surface + ";\n"
            + "@define-color theme_fg_color " + p.text + ";\n"
            + "@define-color theme_base_color " + p.background + ";\n"
            + "@define-color theme_text_color " + p.text + ";\n"
            + "@define-color theme_selected_bg_color " + p.accent + ";\n"
            + "@define-color theme_selected_fg_color " + p.accentText + ";\n"
            + "@define-color insensitive_bg_color " + p.surface + ";\n"
            + "@define-color insensitive_fg_color " + p.subtext + ";\n"
            + "@define-color borders " + p.overlay + ";\n"
            + "@define-color warning_color " + p.warning + ";\n"
            + "@define-color error_color " + p.danger + ";\n"
            + "@define-color success_color " + p.success + ";\n"
            + "@define-color window_bg_color " + p.background + ";\n"
            + "@define-color window_fg_color " + p.text + ";\n"
            + "@define-color view_bg_color " + p.surface + ";\n"
            + "@define-color view_fg_color " + p.text + ";\n"
            + "@define-color headerbar_bg_color " + p.surface + ";\n"
            + "@define-color headerbar_fg_color " + p.text + ";\n"
            + "@define-color card_bg_color " + p.surfaceHigh + ";\n"
            + "@define-color card_fg_color " + p.text + ";\n"
            + "@define-color popover_bg_color " + p.surfaceHigh + ";\n"
            + "@define-color popover_fg_color " + p.text + ";\n"
            + "@define-color sidebar_bg_color " + p.surface + ";\n"
            + "@define-color sidebar_fg_color " + p.text + ";\n"
            + "@define-color accent_color " + p.accent + ";\n"
            + "@define-color accent_bg_color " + p.accent + ";\n"
            + "@define-color accent_fg_color " + p.accentText + ";\n"
            + "@define-color destructive_color " + p.danger + ";\n"
            + "@define-color destructive_bg_color " + p.danger + ";\n"
            + "@define-color destructive_fg_color " + p.accentText + ";\n"
            + "@define-color success_bg_color " + p.success + ";\n"
            + "@define-color success_fg_color " + p.accentText + ";\n"
            + "@define-color warning_bg_color " + p.warning + ";\n"
            + "@define-color warning_fg_color " + p.accentText + ";\n"
            + "@define-color error_bg_color " + p.danger + ";\n"
            + "@define-color error_fg_color " + p.accentText + ";\n";
    }

    function buildKdeScheme(p) {
        const n = (label) => label.replace(/[^A-Za-z0-9]/g, "");
        return "[General]\n"
            + "Name=Helios\n"
            + "ColorScheme=Helios\n\n"
            + "[Colors:Window]\n"
            + "BackgroundNormal=" + root.rgb(p.background) + "\n"
            + "ForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[Colors:View]\n"
            + "BackgroundNormal=" + root.rgb(p.surface) + "\n"
            + "ForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[Colors:Button]\n"
            + "BackgroundNormal=" + root.rgb(p.surfaceHigh) + "\n"
            + "ForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[Colors:Selection]\n"
            + "BackgroundNormal=" + root.rgb(p.accent) + "\n"
            + "ForegroundNormal=" + root.rgb(p.accentText) + "\n\n"
            + "[Colors:Tooltip]\n"
            + "BackgroundNormal=" + root.rgb(p.surfaceHigh) + "\n"
            + "ForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[WM]\n"
            + "activeBackground=" + root.rgb(p.surface) + "\n"
            + "activeForeground=" + root.rgb(p.text) + "\n"
            + "inactiveBackground=" + root.rgb(p.surface) + "\n"
            + "inactiveForeground=" + root.rgb(p.subtext) + "\n";
    }

    // kdeglobals holds a lot of user config we don't own (fonts, shortcuts,
    // recents...) — only the [Colors:*]/[WM]/[General]ColorScheme keys are
    // replaced, everything else in the file is preserved as-is.
    function mergeKdeGlobals(existing, p) {
        let text = existing || "";
        const sections = ["Colors:Window", "Colors:View", "Colors:Button", "Colors:Selection", "Colors:Tooltip", "WM"];
        for (const s of sections) {
            const re = new RegExp("\\[" + s.replace(":", "\\:") + "\\][^\\[]*", "g");
            text = text.replace(re, "");
        }
        if (/\[General\]/.test(text)) {
            if (/^ColorScheme=.*$/m.test(text)) {
                text = text.replace(/^ColorScheme=.*$/m, "ColorScheme=Helios");
            } else {
                text = text.replace(/\[General\]/, "[General]\nColorScheme=Helios");
            }
        } else {
            text += "\n[General]\nColorScheme=Helios\n";
        }
        text = text.replace(/\n{3,}/g, "\n\n");
        return text.replace(/\s+$/, "") + "\n\n"
            + "[Colors:Window]\nBackgroundNormal=" + root.rgb(p.background) + "\nForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[Colors:View]\nBackgroundNormal=" + root.rgb(p.surface) + "\nForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[Colors:Button]\nBackgroundNormal=" + root.rgb(p.surfaceHigh) + "\nForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[Colors:Selection]\nBackgroundNormal=" + root.rgb(p.accent) + "\nForegroundNormal=" + root.rgb(p.accentText) + "\n\n"
            + "[Colors:Tooltip]\nBackgroundNormal=" + root.rgb(p.surfaceHigh) + "\nForegroundNormal=" + root.rgb(p.text) + "\n\n"
            + "[WM]\nactiveBackground=" + root.rgb(p.surface) + "\nactiveForeground=" + root.rgb(p.text)
            + "\ninactiveBackground=" + root.rgb(p.surface) + "\ninactiveForeground=" + root.rgb(p.subtext) + "\n";
    }

    function writeSystemThemeFiles() {
        const p = root.pendingPalette;
        if (!p) return;
        const home = Quickshell.env("HOME");
        const css = root.buildGtkCss(p);

        gtk3File.path = home + "/.config/gtk-3.0/gtk.css";
        gtk3File.setText(css);
        gtk4File.path = home + "/.config/gtk-4.0/gtk.css";
        gtk4File.setText(css);

        kdeSchemeFile.path = home + "/.local/share/color-schemes/Helios.colors";
        kdeSchemeFile.setText(root.buildKdeScheme(p));

        kdeGlobalsFile.path = home + "/.config/kdeglobals";
        kdeGlobalsFile.setText(root.mergeKdeGlobals(kdeGlobalsFile.text(), p));

        gsettingsProc.command = ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
            root.isDark(p.background) ? "prefer-dark" : "default"];
        gsettingsProc.running = false;
        gsettingsProc.running = true;

        // Best-effort: each of these is an independent adapter, called so one
        // app's config quirks (missing file, unexpected format) can't stop
        // the others from getting themed.
        const appAdapters = [
            ["ghostty", () => ThemeGhostty.writeGhosttyTheme(p)],
            ["kitty", () => ThemeKitty.writeKittyTheme(p)],
            ["btop", () => ThemeBtop.writeBtopTheme(p)],
            ["nvim", () => ThemeNvim.writeNvimTheme(p)],
            ["zed", () => ThemeZed.writeZedTheme(p)],
            ["bat", () => ThemeBat.writeBatTheme(p)],
            ["firefox", () => ThemeFirefox.writeFirefoxTheme(p)],
            ["hyprland", () => ThemeHyprland.writeHyprlandTheme(p)],
            ["yazi", () => ThemeYazi.writeYaziTheme(p)],
            ["alacritty", () => ThemeAlacritty.writeAlacrittyTheme(p)],
            ["wezterm", () => ThemeWezterm.writeWeztermTheme(p)],
            ["tmux", () => ThemeTmux.writeTmuxTheme(p)],
            ["vscode", () => ThemeVscode.writeVscodeTheme(p)],
            ["kiro", () => ThemeKiro.writeKiroTheme(p)],
            ["rofi", () => ThemeRofi.writeRofiTheme(p)],
            ["wofi", () => ThemeWofi.writeWofiTheme(p)]
        ];
        for (const [name, write] of appAdapters) {
            try { write(); } catch (e) { console.warn("Helios theme: " + name + " failed", e); }
        }
    }

    property FileView gtk3File: FileView { printErrors: false; atomicWrites: true }
    property FileView gtk4File: FileView { printErrors: false; atomicWrites: true }
    property FileView kdeSchemeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView kdeGlobalsFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
    property Process gsettingsProc: Process {}

    // --- Persistence --------------------------------------------------------

    // Applies whatever's currently in settingsAdapter to Colors. Called both
    // at startup and whenever settingsFile finishes loading — blockLoading
    // guarantees the raw file bytes are read synchronously, but JsonAdapter's
    // own parse-and-populate of mode/presetName/dynamicPaletteLight/
    // dynamicPaletteDark from that data happens on a later tick, after
    // Component.onCompleted has already run.
    // So onCompleted alone raced the adapter and always saw its "helios"
    // defaults; restoring here too, on the FileView's loaded signal, is what
    // actually picks up the saved theme.
    function restoreFromSettings() {
        if (root.mode === "dynamic") {
            const cached = root.dynamicDark ? settingsAdapter.dynamicPaletteDark : settingsAdapter.dynamicPaletteLight;
            if (cached) {
                try {
                    Colors.apply(JSON.parse(cached));
                    return;
                } catch (e) { /* fall through to the Helios default below */ }
            }
            Colors.apply(root.deriveFullPalette(root.presets.helios));
        } else {
            Colors.apply(root.deriveFullPalette(root.presets[root.presetName] || root.presets.helios));
        }
    }

    Component.onCompleted: root.restoreFromSettings()

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("theme.json")
        watchChanges: true
        blockLoading: true
        preload: true
        onLoaded: root.restoreFromSettings()

        JsonAdapter {
            id: settingsAdapter
            property string mode: "preset"
            property string presetName: "helios"
            property string paletteScheme: "scheme-tonal-spot"
            property bool dynamicDark: true
            property string dynamicPaletteLight: ""
            property string dynamicPaletteDark: ""
        }
    }
}
