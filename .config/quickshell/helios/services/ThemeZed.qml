pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Zed
QtObject {
    id: root

    // transparent variants keep every color but alpha the surface/background
    // family (dank-zed-theme.json's "B6" convention) and drop the opaque
    // window background so the compositor's blur shows through.
    function buildZedStyle(p, transparent) {
        const isDark = Themes.isDark(p.background);
        const alpha = (hex, aa) => hex + aa;
        const bg = (hex) => transparent ? alpha(hex, "B6") : hex;
        const syn = (color, style, weight) => ({ color: color, font_style: style || null, font_weight: weight || null });

        const style = {
            accents: [p.accent, p.success, p.warning],
            "background.appearance": transparent ? "blurred" : "opaque",
            border: p.overlay, "border.variant": p.overlay, "border.focused": p.accent,
            "border.selected": p.accent, "border.transparent": "#00000000", "border.disabled": p.overlay,
            "elevated_surface.background": bg(p.surfaceHigh), "surface.background": bg(p.surface),
            background: transparent ? null : p.background,
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
            "status_bar.background": bg(p.surface), "title_bar.background": bg(p.surface),
            "title_bar.inactive_background": bg(p.surface), "toolbar.background": bg(p.background),
            "tab_bar.background": bg(p.surface), "tab.inactive_background": bg(p.surface), "tab.active_background": bg(p.background),
            "search.match_background": alpha(p.accent, "55"),
            "panel.background": bg(p.surface), "panel.focused_border": p.accent, "pane.focused_border": p.accent,
            "scrollbar.thumb.background": alpha(p.overlay, "80"), "scrollbar.thumb.hover_background": p.overlay,
            "scrollbar.thumb.border": "#00000000", "scrollbar.track.background": "#00000000", "scrollbar.track.border": "#00000000",
            "editor.foreground": p.text, "editor.background": bg(p.background), "editor.gutter.background": bg(p.background),
            "editor.subheader.background": bg(p.surface), "editor.indent_guide": alpha(p.overlay, "40"),
            "editor.indent_guide_active": p.overlay, "editor.active_line.background": alpha(p.surface, "80"),
            "editor.highlighted_line.background": alpha(p.surfaceHigh, "80"), "editor.line_number": p.subtext,
            "editor.active_line_number": p.text, "editor.invisible": p.overlay,
            "editor.wrap_guide": alpha(p.overlay, "30"), "editor.active_wrap_guide": alpha(p.overlay, "60"),
            "editor.document_highlight.read_background": alpha(p.accent, "22"),
            "editor.document_highlight.write_background": alpha(p.accent, "33"),
            "terminal.background": bg(p.background), "terminal.foreground": p.text,
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

        return style;
    }

    function buildZedTheme(p) {
        const isDark = Themes.isDark(p.background);
        const appearance = isDark ? "dark" : "light";
        return {
            "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
            name: "Helios",
            author: "helios",
            themes: [
                { name: "Helios", appearance: appearance, style: root.buildZedStyle(p, false) },
                { name: "Helios Transparent", appearance: appearance, style: root.buildZedStyle(p, true) }
            ]
        };
    }

    // settings.json is JSONC (comments, trailing commas) — a strict
    // JSON.parse/stringify round-trip would blow up or drop the user's
    // comments, so this only surgically replaces the "theme" block's
    // mode/light/dark keys, same philosophy as mergeKdeGlobals in Themes.qml.
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
        zedSettingsFile.setText(root.mergeZedSettings(zedSettingsFile.text(), Themes.isDark(p.background)));
    }

    property FileView zedThemeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView zedSettingsFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
}
