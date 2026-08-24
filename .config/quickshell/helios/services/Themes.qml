pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Theme presets + persistence + system app theming (GTK/KDE, Ghostty, btop,
// Neovim, Zed, Bat, best-effort Firefox), and dynamic theme generation from
// the current wallpaper via matugen. Colors.qml holds the live palette the
// shell UI binds to; this singleton owns picking one and pushing it in.
QtObject {
    id: root

    readonly property var presets: ({
        helios: {
            label: "Helios", background: "#14121a", surface: "#282331", surfaceHigh: "#3a3342",
            overlay: "#6f6580", text: "#eae6f0", subtext: "#b3a9c4", accent: "#f0a868",
            accentText: "#2c1c0f", danger: "#e5707e", warning: "#eec172", success: "#8fd08a"
        },
        kanagawa: {
            label: "Kanagawa", background: "#1f1f28", surface: "#2a2a37", surfaceHigh: "#363646",
            overlay: "#727169", text: "#dcd7ba", subtext: "#c8c093", accent: "#7e9cd8",
            accentText: "#1f1f28", danger: "#e46876", warning: "#dca561", success: "#98bb6c"
        },
        tokyonight: {
            label: "Tokyo Night", background: "#1a1b26", surface: "#24283b", surfaceHigh: "#2f334d",
            overlay: "#565f89", text: "#c0caf5", subtext: "#a9b1d6", accent: "#7aa2f7",
            accentText: "#1a1b26", danger: "#f7768e", warning: "#e0af68", success: "#9ece6a"
        },
        dracula: {
            label: "Dracula", background: "#282a36", surface: "#2f3241", surfaceHigh: "#3c3f51",
            overlay: "#6272a4", text: "#f8f8f2", subtext: "#bfbfda", accent: "#bd93f9",
            accentText: "#282a36", danger: "#ff5555", warning: "#f1fa8c", success: "#50fa7b"
        },
        gruvbox: {
            label: "Gruvbox", background: "#1d2021", surface: "#282828", surfaceHigh: "#3c3836",
            overlay: "#7c6f64", text: "#ebdbb2", subtext: "#d5c4a1", accent: "#d79921",
            accentText: "#1d2021", danger: "#fb4934", warning: "#fabd2f", success: "#b8bb26"
        },
        catppuccinMocha: {
            label: "Catppuccin Mocha", background: "#1e1e2e", surface: "#181825", surfaceHigh: "#313244",
            overlay: "#6c7086", text: "#cdd6f4", subtext: "#a6adc8", accent: "#cba6f7",
            accentText: "#1e1e2e", danger: "#f38ba8", warning: "#f9e2af", success: "#a6e3a1"
        },
        catppuccinLatte: {
            label: "Catppuccin Latte", background: "#eff1f5", surface: "#e6e9ef", surfaceHigh: "#dce0e8",
            overlay: "#9ca0b0", text: "#4c4f69", subtext: "#5c5f77", accent: "#8839ef",
            accentText: "#eff1f5", danger: "#d20f39", warning: "#df8e1d", success: "#40a02b"
        },
        gruvboxLight: {
            label: "Gruvbox Light", background: "#fbf1c7", surface: "#ebdbb2", surfaceHigh: "#d5c4a1",
            overlay: "#7c6f64", text: "#3c3836", subtext: "#504945", accent: "#af3a03",
            accentText: "#fbf1c7", danger: "#9d0006", warning: "#b57614", success: "#79740e"
        },
        kanagawaLotus: {
            label: "Kanagawa Lotus", background: "#f2ecbc", surface: "#e5ddb0", surfaceHigh: "#dcd5ac",
            overlay: "#716e61", text: "#545464", subtext: "#8a8980", accent: "#4d699b",
            accentText: "#f2ecbc", danger: "#c84053", warning: "#e98a00", success: "#6f894e"
        },
        tokyoNightDay: {
            label: "Tokyo Night Day", background: "#e1e2e7", surface: "#d0d5e3", surfaceHigh: "#c4c8da",
            overlay: "#b4b5b9", text: "#3760bf", subtext: "#6172b0", accent: "#2e7de9",
            accentText: "#e1e2e7", danger: "#f52a65", warning: "#8c6c3e", success: "#587539"
        },
        rosePineDawn: {
            label: "Rosé Pine Dawn", background: "#faf4ed", surface: "#fffaf3", surfaceHigh: "#f2e9e1",
            overlay: "#9893a5", text: "#464261", subtext: "#797593", accent: "#907aa9",
            accentText: "#faf4ed", danger: "#b4637a", warning: "#ea9d34", success: "#6d8f89"
        },
        solarizedLight: {
            label: "Solarized Light", background: "#fdf6e3", surface: "#eee8d5", surfaceHigh: "#e3dcc6",
            overlay: "#93a1a1", text: "#657b83", subtext: "#839496", accent: "#268bd2",
            accentText: "#fdf6e3", danger: "#dc322f", warning: "#b58900", success: "#859900"
        }
    })

    readonly property var presetOrder: ["helios", "kanagawa", "tokyonight", "dracula", "gruvbox", "catppuccinMocha", "catppuccinLatte", "gruvboxLight", "kanagawaLotus", "tokyoNightDay", "rosePineDawn", "solarizedLight"]

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
            Quickshell.env("HOME") + "/.config/btop/themes",
            Quickshell.env("HOME") + "/.config/nvim/lua",
            Quickshell.env("HOME") + "/.config/zed/themes",
            Quickshell.env("HOME") + "/.config/bat/themes"]
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

        // Best-effort: each of these is independent and wrapped so one
        // app's config quirks (missing file, unexpected format) can't stop
        // the others from getting themed.
        try { root.writeGhosttyTheme(p); } catch (e) { console.warn("Helios theme: ghostty failed", e); }
        try { root.writeBtopTheme(p); } catch (e) { console.warn("Helios theme: btop failed", e); }
        try { root.writeNvimTheme(p); } catch (e) { console.warn("Helios theme: nvim failed", e); }
        try { root.writeZedTheme(p); } catch (e) { console.warn("Helios theme: zed failed", e); }
        try { root.writeBatTheme(p); } catch (e) { console.warn("Helios theme: bat failed", e); }
        try { root.writeFirefoxTheme(p); } catch (e) { console.warn("Helios theme: firefox failed", e); }
        try { root.writeHyprlandTheme(p); } catch (e) { console.warn("Helios theme: hyprland failed", e); }
    }

    // --- Hyprland (border colors, via the hyprland-lua-config plugin) -------

    function buildHyprlandTheme(p) {
        const active = root.hexToRgbColor(p.accent);
        const inactive = root.hexToRgbColor(p.surface);
        const locked = root.hexToRgbColor(p.danger);
        const textOnActive = root.hexToRgbColor(p.accentText);
        const textOnInactive = root.hexToRgbColor(p.text);
        return "-- Generated by Helios (Themes.qml) — do not edit by hand\n\n"
            + "local active = \"" + active + "\"\n"
            + "local inactive = \"" + inactive + "\"\n"
            + "local locked = \"" + locked + "\"\n"
            + "local text_active = \"" + textOnActive + "\"\n"
            + "local text_inactive = \"" + textOnInactive + "\"\n\n"
            + "local function apply_theme()\n"
            + "    hl.config({\n"
            + "        general = {\n"
            + "            col = {\n"
            + "                active_border = active,\n"
            + "                inactive_border = inactive,\n"
            + "            },\n"
            + "        },\n"
            + "        group = {\n"
            + "            col = {\n"
            + "                border_active = active,\n"
            + "                border_inactive = inactive,\n"
            + "                border_locked_active = locked,\n"
            + "                border_locked_inactive = inactive,\n"
            + "            },\n\n"
            + "            groupbar = {\n"
            + "                gradients = true,\n"
            + "                col = {\n"
            + "                    active = active,\n"
            + "                    inactive = inactive,\n"
            + "                    locked_active = locked,\n"
            + "                    locked_inactive = inactive,\n"
            + "                },\n"
            + "                text_color = text_active,\n"
            + "                text_color_inactive = text_inactive,\n"
            + "                text_color_locked_active = text_active,\n"
            + "                text_color_locked_inactive = text_inactive,\n"
            + "            },\n"
            + "        },\n"
            + "    })\n"
            + "end\n\n"
            + "return {\n"
            + "    apply_theme = apply_theme\n"
            + "}\n";
    }

    // Hyprland's lua config plugin takes colors as "rgb(RRGGBB)" strings
    // (see noctalia.lua) rather than the "#rrggbb" hex Colors.qml uses.
    function hexToRgbColor(hex) {
        return "rgb(" + hex.replace("#", "").toUpperCase() + ")";
    }

    function writeHyprlandTheme(p) {
        const home = Quickshell.env("HOME");
        heliosLuaFile.path = home + "/.config/hypr/helios.lua";
        heliosLuaFile.setText(root.buildHyprlandTheme(p));
        // Re-sources the whole lua config (hyprland.lua requires this file
        // and calls apply_theme() on load) so the new border colors take
        // effect immediately instead of waiting for the next manual reload.
        hyprctlReloadProc.running = false;
        hyprctlReloadProc.running = true;
    }

    property FileView heliosLuaFile: FileView { printErrors: false; atomicWrites: true }
    property Process hyprctlReloadProc: Process { command: ["hyprctl", "reload"] }

    // --- Ghostty --------------------------------------------------------

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

    // --- btop -------------------------------------------------------------

    function buildBtopTheme(p) {
        const grad = (key) => "theme[" + key + "_start]=\"" + p.success + "\"\n"
            + "theme[" + key + "_mid]=\"" + p.warning + "\"\n"
            + "theme[" + key + "_end]=\"" + p.danger + "\"\n";
        return "# btop theme generated by Helios\n\n"
            + "theme[main_bg]=\"" + p.background + "\"\n"
            + "theme[main_fg]=\"" + p.text + "\"\n"
            + "theme[title]=\"" + p.accent + "\"\n"
            + "theme[hi_fg]=\"" + p.accent + "\"\n"
            + "theme[selected_bg]=\"" + p.surfaceHigh + "\"\n"
            + "theme[selected_fg]=\"" + p.text + "\"\n"
            + "theme[inactive_fg]=\"" + p.subtext + "\"\n"
            + "theme[proc_misc]=\"" + p.subtext + "\"\n"
            + "theme[cpu_box]=\"" + p.overlay + "\"\n"
            + "theme[mem_box]=\"" + p.overlay + "\"\n"
            + "theme[net_box]=\"" + p.overlay + "\"\n"
            + "theme[proc_box]=\"" + p.overlay + "\"\n"
            + "theme[div_line]=\"" + p.overlay + "\"\n"
            + grad("temp") + grad("cpu") + grad("free") + grad("cached")
            + grad("available") + grad("used") + grad("download") + grad("upload");
    }

    function writeBtopTheme(p) {
        const home = Quickshell.env("HOME");
        btopThemeFile.path = home + "/.config/btop/themes/helios.theme";
        btopThemeFile.setText(root.buildBtopTheme(p));

        btopConfigFile.path = home + "/.config/btop/btop.conf";
        const existing = btopConfigFile.text();
        const text = /^color_theme\s*=.*$/m.test(existing)
            ? existing.replace(/^color_theme\s*=.*$/m, 'color_theme = "helios"')
            : existing.replace(/\s*$/, "") + '\ncolor_theme = "helios"\n';
        btopConfigFile.setText(text);
    }

    property FileView btopThemeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView btopConfigFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }

    // --- Neovim -------------------------------------------------------------

    // Matches this machine's existing nvim setup exactly: lua/matugen.lua is
    // a generated base16-colorscheme.nvim palette + Telescope highlight
    // overrides, hot-reloaded by a SIGUSR1 handler already registered in
    // that same file. We only need to overwrite it with new colors in the
    // same shape and signal any running nvim to pick it up.
    function buildNvimTheme(p) {
        const hi = (group, fg, bg) => "  hi('" + group + "', { fg = '" + fg + "', bg = '" + bg + "' })\n";
        return "local M = {}\n\n"
            + "function M.setup()\n"
            // base16-colorscheme.nvim never touches &background, so plugins
            // that branch on it (devicons, etc.) keep assuming dark and fall
            // back to near-black colors once we hand them a light palette.
            + "  vim.o.background = '" + (root.isDark(p.background) ? "dark" : "light") + "'\n"
            + "  require('base16-colorscheme').setup({\n"
            + "    base00 = '" + p.background + "',\n"
            + "    base01 = '" + p.surface + "',\n"
            + "    base02 = '" + p.surfaceHigh + "',\n"
            + "    base03 = '" + p.overlay + "',\n"
            + "    base04 = '" + p.subtext + "',\n"
            + "    base05 = '" + p.text + "',\n"
            + "    base06 = '" + p.text + "',\n"
            + "    base07 = '" + p.text + "',\n"
            + "    base08 = '" + p.danger + "',\n"
            + "    base09 = '" + p.warning + "',\n"
            + "    base0A = '" + p.warning + "',\n"
            + "    base0B = '" + p.success + "',\n"
            + "    base0C = '" + p.accent + "',\n"
            + "    base0D = '" + p.accent + "',\n"
            + "    base0E = '" + p.accent + "',\n"
            + "    base0F = '" + p.danger + "',\n"
            + "  })\n\n"
            + "  local hi = function(group, opts)\n"
            + "    vim.api.nvim_set_hl(0, group, opts)\n"
            + "  end\n\n"
            + hi("TelescopeNormal", p.text, p.background)
            + hi("TelescopeBorder", p.overlay, p.background)
            + hi("TelescopePromptNormal", p.text, p.background)
            + hi("TelescopePromptBorder", p.overlay, p.background)
            + hi("TelescopePromptPrefix", p.accent, p.background)
            + hi("TelescopePromptCounter", p.subtext, p.background)
            + hi("TelescopePromptTitle", p.accentText, p.accent)
            + hi("TelescopePreviewTitle", p.accentText, p.accent)
            + hi("TelescopeResultsTitle", p.accentText, p.accent)
            + hi("TelescopeSelection", p.text, p.surfaceHigh)
            + hi("TelescopeSelectionCaret", p.accent, p.surfaceHigh)
            + "  hi('TelescopeMatching', { fg = '" + p.accent + "', bold = true })\n"
            + "end\n\n"
            + " -- Register a signal handler for SIGUSR1 (matugen updates)\n"
            + " local signal = vim.uv.new_signal()\n"
            + " signal:start(\n"
            + "   'sigusr1',\n"
            + "   vim.schedule_wrap(function()\n"
            + "     package.loaded['matugen'] = nil\n"
            + "     require('matugen').setup()\n"
            + "   end)\n"
            + " )\n\n"
            + " return M\n";
    }

    function writeNvimTheme(p) {
        const home = Quickshell.env("HOME");
        nvimThemeFile.path = home + "/.config/nvim/lua/matugen.lua";
        nvimThemeFile.setText(root.buildNvimTheme(p));
        // Nudges any already-running nvim instances via the SIGUSR1 handler
        // that file registers — harmless (just exits nonzero) if none are
        // running.
        nvimSignalProc.running = false;
        nvimSignalProc.running = true;
    }

    property FileView nvimThemeFile: FileView { printErrors: false; atomicWrites: true }
    property Process nvimSignalProc: Process { command: ["pkill", "-USR1", "-x", "nvim"] }

    // --- Zed ----------------------------------------------------------------

    function buildZedTheme(p) {
        const isDark = root.isDark(p.background);
        const alpha = (hex, aa) => hex + aa;
        const syn = (color, style, weight) => ({ color: color, font_style: style || null, font_weight: weight || null });

        const style = {
            accents: [p.accent, p.success, p.warning],
            "background.appearance": isDark ? "dark" : "light",
            border: p.overlay, "border.variant": p.overlay, "border.focused": p.accent,
            "border.selected": p.accent, "border.transparent": "#00000000", "border.disabled": p.overlay,
            "elevated_surface.background": p.surfaceHigh, "surface.background": p.surface, background: p.background,
            "element.background": p.surface, "element.hover": p.surfaceHigh, "element.active": p.surfaceHigh,
            "element.selected": p.surfaceHigh, "element.disabled": p.surface,
            "drop_target.background": alpha(p.accent, "22"),
            "ghost_element.background": "#00000000", "ghost_element.hover": p.surfaceHigh,
            "ghost_element.active": p.surfaceHigh, "ghost_element.selected": p.surfaceHigh,
            "ghost_element.disabled": "#00000000",
            text: p.text, "text.muted": p.subtext, "text.placeholder": p.subtext,
            "text.disabled": p.subtext, "text.accent": p.accent,
            icon: p.text, "icon.muted": p.subtext, "icon.disabled": p.subtext,
            "icon.placeholder": p.subtext, "icon.accent": p.accent,
            "status_bar.background": p.surface, "title_bar.background": p.surface,
            "title_bar.inactive_background": p.surface, "toolbar.background": p.background,
            "tab_bar.background": p.surface, "tab.inactive_background": p.surface, "tab.active_background": p.background,
            "search.match_background": alpha(p.accent, "55"),
            "panel.background": p.surface, "panel.focused_border": p.accent, "pane.focused_border": p.accent,
            "scrollbar.thumb.background": alpha(p.overlay, "80"), "scrollbar.thumb.hover_background": p.overlay,
            "scrollbar.thumb.border": "#00000000", "scrollbar.track.background": "#00000000", "scrollbar.track.border": "#00000000",
            "editor.foreground": p.text, "editor.background": p.background, "editor.gutter.background": p.background,
            "editor.subheader.background": p.surface, "editor.indent_guide": alpha(p.overlay, "40"),
            "editor.indent_guide_active": p.overlay, "editor.active_line.background": alpha(p.surface, "80"),
            "editor.highlighted_line.background": alpha(p.surfaceHigh, "80"), "editor.line_number": p.subtext,
            "editor.active_line_number": p.text, "editor.invisible": p.overlay,
            "editor.wrap_guide": alpha(p.overlay, "30"), "editor.active_wrap_guide": alpha(p.overlay, "60"),
            "editor.document_highlight.read_background": alpha(p.accent, "22"),
            "editor.document_highlight.write_background": alpha(p.accent, "33"),
            "terminal.background": p.background, "terminal.foreground": p.text,
            "terminal.bright_foreground": p.text, "terminal.dim_foreground": p.subtext,
            "terminal.ansi.black": p.surfaceHigh, "terminal.ansi.bright_black": p.overlay, "terminal.ansi.dim_black": p.surface,
            "terminal.ansi.red": p.danger, "terminal.ansi.bright_red": p.danger, "terminal.ansi.dim_red": p.danger,
            "terminal.ansi.green": p.success, "terminal.ansi.bright_green": p.success, "terminal.ansi.dim_green": p.success,
            "terminal.ansi.yellow": p.warning, "terminal.ansi.bright_yellow": p.warning, "terminal.ansi.dim_yellow": p.warning,
            "terminal.ansi.blue": p.accent, "terminal.ansi.bright_blue": p.accent, "terminal.ansi.dim_blue": p.accent,
            "terminal.ansi.magenta": p.accent, "terminal.ansi.bright_magenta": p.accent, "terminal.ansi.dim_magenta": p.accent,
            "terminal.ansi.cyan": p.accent, "terminal.ansi.bright_cyan": p.accent, "terminal.ansi.dim_cyan": p.accent,
            "terminal.ansi.white": p.text, "terminal.ansi.bright_white": p.text, "terminal.ansi.dim_white": p.subtext,
            "link_text.hover": p.accent,
            players: [
                { cursor: p.accent, background: alpha(p.accent, "80"), selection: alpha(p.accent, "60") },
                { cursor: p.success, background: alpha(p.success, "80"), selection: alpha(p.success, "60") },
                { cursor: p.warning, background: alpha(p.warning, "80"), selection: alpha(p.warning, "60") },
                { cursor: p.danger, background: alpha(p.danger, "80"), selection: alpha(p.danger, "60") }
            ],
            syntax: {
                boolean: syn(p.warning), comment: syn(p.subtext, "italic"), "comment.doc": syn(p.subtext, "italic"),
                constant: syn(p.warning), constructor: syn(p.accent), emphasis: syn(p.text, "italic"),
                "emphasis.strong": syn(p.text, null, 700), function: syn(p.accent), keyword: syn(p.danger),
                number: syn(p.warning), operator: syn(p.subtext), property: syn(p.text),
                punctuation: syn(p.subtext), "punctuation.bracket": syn(p.subtext), "punctuation.delimiter": syn(p.subtext),
                "punctuation.list_marker": syn(p.subtext), "punctuation.special": syn(p.accent),
                string: syn(p.success), "string.escape": syn(p.warning), "string.regex": syn(p.warning),
                "string.special": syn(p.success), "string.special.symbol": syn(p.success), tag: syn(p.danger),
                "text.literal": syn(p.success), type: syn(p.accent), variable: syn(p.text), "variable.special": syn(p.accent)
            }
        };

        const statusColor = {
            conflict: p.warning, created: p.success, deleted: p.danger, error: p.danger,
            hidden: p.subtext, hint: p.accent, ignored: p.subtext, info: p.accent,
            modified: p.warning, predictive: p.subtext, renamed: p.accent, success: p.success,
            unreachable: p.subtext, warning: p.warning
        };
        for (const key in statusColor) {
            const c = statusColor[key];
            style[key] = c;
            style[key + ".background"] = alpha(c, "22");
            style[key + ".border"] = alpha(c, "55");
        }

        return {
            "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
            name: "Helios",
            author: "helios",
            themes: [{ name: "Helios", appearance: isDark ? "dark" : "light", style: style }]
        };
    }

    // settings.json is JSONC (comments, trailing commas) — a strict
    // JSON.parse/stringify round-trip would blow up or drop the user's
    // comments, so this only surgically replaces the "theme" block's
    // mode/light/dark keys, same philosophy as mergeKdeGlobals above.
    function mergeZedSettings(existing, isDark) {
        const text = existing || "{\n}\n";
        const modeVal = isDark ? "dark" : "light";
        if (!/"theme"\s*:\s*\{/.test(text)) {
            const insertion = "\n  \"theme\": {\n    \"mode\": \"" + modeVal + "\",\n    \"dark\": \"Helios\",\n    \"light\": \"Helios\"\n  },";
            return text.replace(/\{/, "{" + insertion);
        }
        return text.replace(/("theme"\s*:\s*\{)([\s\S]*?)(\n?\s*\})/, (m, open, body, close) => {
            let b = body;
            b = /"mode"\s*:\s*"[^"]*"/.test(b) ? b.replace(/"mode"\s*:\s*"[^"]*"/, "\"mode\": \"" + modeVal + "\"") : b + ",\n    \"mode\": \"" + modeVal + "\"";
            const key = modeVal;
            const re = new RegExp("\"" + key + "\"\\s*:\\s*\"[^\"]*\"");
            b = re.test(b) ? b.replace(re, "\"" + key + "\": \"Helios\"") : b + ",\n    \"" + key + "\": \"Helios\"";
            return open + b + close;
        });
    }

    function writeZedTheme(p) {
        const home = Quickshell.env("HOME");
        zedThemeFile.path = home + "/.config/zed/themes/helios.json";
        zedThemeFile.setText(JSON.stringify(root.buildZedTheme(p), null, 2));

        zedSettingsFile.path = home + "/.config/zed/settings.json";
        zedSettingsFile.setText(root.mergeZedSettings(zedSettingsFile.text(), root.isDark(p.background)));
    }

    property FileView zedThemeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView zedSettingsFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }

    // --- bat ------------------------------------------------------------

    function buildBatTheme(p) {
        const rule = (name, scope, color, style) => "        <dict>\n"
            + "            <key>name</key><string>" + name + "</string>\n"
            + "            <key>scope</key><string>" + scope + "</string>\n"
            + "            <key>settings</key><dict>\n"
            + "                <key>foreground</key><string>" + color + "</string>\n"
            + (style ? "                <key>fontStyle</key><string>" + style + "</string>\n" : "")
            + "            </dict>\n"
            + "        </dict>\n";
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            + "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
            + "<plist version=\"1.0\">\n<dict>\n"
            + "    <key>name</key><string>Helios</string>\n"
            + "    <key>settings</key>\n    <array>\n"
            + "        <dict>\n            <key>settings</key>\n            <dict>\n"
            + "                <key>background</key><string>" + p.background + "</string>\n"
            + "                <key>foreground</key><string>" + p.text + "</string>\n"
            + "                <key>caret</key><string>" + p.accent + "</string>\n"
            + "                <key>selection</key><string>" + p.surfaceHigh + "</string>\n"
            + "                <key>lineHighlight</key><string>" + p.surface + "</string>\n"
            + "                <key>invisibles</key><string>" + p.overlay + "</string>\n"
            + "            </dict>\n        </dict>\n"
            + rule("Comment", "comment", p.subtext, "italic")
            + rule("String", "string", p.success, null)
            + rule("Number", "constant.numeric", p.warning, null)
            + rule("Keyword", "keyword", p.danger, null)
            + rule("Storage/Type", "storage, storage.type", p.accent, null)
            + rule("Function", "entity.name.function, support.function", p.accent, null)
            + rule("Variable", "variable", p.text, null)
            + rule("Constant", "constant.language, constant.other", p.warning, null)
            + "    </array>\n"
            + "    <key>uuid</key><string>b8a1c2d3-e4f5-4a6b-9c8d-0e1f2a3b4c5d</string>\n"
            + "</dict>\n</plist>\n";
    }

    function writeBatTheme(p) {
        const home = Quickshell.env("HOME");
        batThemeFile.path = home + "/.config/bat/themes/Helios.tmTheme";
        batThemeFile.setText(root.buildBatTheme(p));

        batConfigFile.path = home + "/.config/bat/config";
        const existing = batConfigFile.text();
        const stripped = existing.split("\n").filter(l => !/^\s*--theme=/.test(l)).join("\n").replace(/\s*$/, "");
        batConfigFile.setText((stripped.length > 0 ? stripped + "\n" : "") + "--theme=\"Helios\"\n");

        batCacheProc.running = false;
        batCacheProc.running = true;
    }

    property FileView batThemeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView batConfigFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
    property Process batCacheProc: Process { command: ["bat", "cache", "--build"] }

    // --- Firefox --------------------------------------------------------

    // Best-effort: only the default profile from a native (non-Flatpak)
    // profiles.ini is handled. userChrome/userContent need
    // toolkit.legacyUserProfileCustomizations.stylesheets enabled — done here
    // via user.js, which (unlike prefs.js) is safe to hand-edit and takes
    // effect on Firefox's next launch.
    function findFirefoxProfile(iniText) {
        if (!iniText) return "";
        const blocks = iniText.split(/\n(?=\[)/);
        for (const b of blocks) {
            if (/^\[Install/.test(b)) {
                const m = b.match(/^Default=(.+)$/m);
                if (m) return m[1].trim();
            }
        }
        for (const b of blocks) {
            if (/^\[Profile/.test(b) && /^Default=1\s*$/m.test(b)) {
                const m = b.match(/^Path=(.+)$/m);
                if (m) return m[1].trim();
            }
        }
        return "";
    }

    function buildFirefoxCss(p) {
        return "/* Generated by Helios (Themes.qml) */\n"
            + ":root {\n"
            + "  --helios-bg: " + p.background + ";\n"
            + "  --helios-surface: " + p.surface + ";\n"
            + "  --helios-text: " + p.text + ";\n"
            + "  --helios-accent: " + p.accent + ";\n"
            + "}\n"
            + "#navigator-toolbox, #TabsToolbar, #nav-bar { background-color: var(--helios-surface) !important; }\n"
            + "#tabbrowser-tabs .tab-background[selected] { background-color: var(--helios-bg) !important; }\n"
            + ":root, .tab-label, #urlbar { color: var(--helios-text) !important; }\n"
            + "#urlbar-background { background-color: var(--helios-bg) !important; }\n";
    }

    function writeFirefoxTheme(p) {
        const home = Quickshell.env("HOME");
        firefoxIniFile.path = home + "/.mozilla/firefox/profiles.ini";
        const profile = root.findFirefoxProfile(firefoxIniFile.text());
        if (!profile) return; // No native profile found — skip silently.

        const profileDir = home + "/.mozilla/firefox/" + profile;

        firefoxUserJsFile.path = profileDir + "/user.js";
        const existingUserJs = firefoxUserJsFile.text();
        const pref = "toolkit.legacyUserProfileCustomizations.stylesheets";
        if (existingUserJs.indexOf(pref) < 0) {
            firefoxUserJsFile.setText((existingUserJs || "").replace(/\s*$/, "")
                + "\nuser_pref(\"" + pref + "\", true);\n");
        }

        root.pendingFirefoxCss = root.buildFirefoxCss(p);
        root.pendingFirefoxProfileDir = profileDir;
        firefoxMkdirProc.command = ["mkdir", "-p", profileDir + "/chrome"];
        firefoxMkdirProc.running = false;
        firefoxMkdirProc.running = true;
    }

    property string pendingFirefoxCss: ""
    property string pendingFirefoxProfileDir: ""

    property FileView firefoxIniFile: FileView { printErrors: false; preload: true; blockLoading: true }
    property FileView firefoxUserJsFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
    property FileView firefoxChromeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView firefoxContentFile: FileView { printErrors: false; atomicWrites: true }
    property Process firefoxMkdirProc: Process {
        onExited: {
            if (!root.pendingFirefoxProfileDir) return;
            firefoxChromeFile.path = root.pendingFirefoxProfileDir + "/chrome/userChrome.css";
            firefoxChromeFile.setText(root.pendingFirefoxCss);
            firefoxContentFile.path = root.pendingFirefoxProfileDir + "/chrome/userContent.css";
            firefoxContentFile.setText(root.pendingFirefoxCss);
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
