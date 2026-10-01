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
    //
    // Key set and alpha conventions mirror Zed's official Catppuccin theme
    // (github.com/catppuccin/zed) so Helios covers the same surface, so
    // nothing in the editor falls back to an unthemed default.
    function buildZedStyle(p, transparent) {
        const isDark = Themes.isDark(p.background);
        const alpha = (hex, aa) => hex + aa;
        const bg = (hex) => transparent ? alpha(hex, "B6") : hex;
        const syn = (color, style, weight) => ({ color: color, font_style: style || null, font_weight: weight || null });
        // Borders as a lightness step off the background itself, rather than
        // a separate palette color — lighter in dark themes, darker in light
        // ones, so the border always reads as "the edge of this surface".
        const shade = (hex, delta) => {
            const c = Qt.color(hex);
            const l = isDark ? Math.min(c.hslLightness + delta, 1) : Math.max(c.hslLightness - delta, 0);
            return Qt.hsla(c.hslHue, c.hslSaturation, l, 1.0).toString();
        };
        const borderColor = shade(p.background, 0.12), borderSubtle = shade(p.background, 0.08);

        // Helios only has six distinct hues to work with, versus Catppuccin's
        // eight-color accent system — kw/fn/doc/num/str/err cover keyword,
        // function/property, label/docs, constant/type, string, and
        // error/builtin roles respectively, reused across related tokens.
        const kw = p.accent, fn = p.secondary, doc = p.tertiary,
              num = p.warning, str = p.success, err = p.danger,
              txt = p.text, sub = p.subtext;

        const style = {
            accents: [p.accent, p.secondary, p.tertiary, p.success, p.warning, p.danger],

            "vim.mode.text": p.accentText,
            "vim.normal.foreground": p.accentText, "vim.helix_normal.foreground": p.accentText,
            "vim.visual.foreground": p.accentText, "vim.helix_select.foreground": p.accentText,
            "vim.insert.foreground": p.accentText, "vim.visual_line.foreground": p.accentText,
            "vim.visual_block.foreground": p.accentText, "vim.replace.foreground": p.accentText,
            "vim.normal.background": p.accent, "vim.helix_normal.background": p.accent,
            "vim.visual.background": p.secondary, "vim.helix_select.background": p.secondary,
            "vim.insert.background": p.success, "vim.visual_line.background": p.secondary,
            "vim.visual_block.background": p.tertiary, "vim.replace.background": p.danger,

            "background.appearance": transparent ? "blurred" : "opaque",
            border: borderColor, "border.variant": borderSubtle, "border.focused": p.accent,
            "border.selected": p.accent, "border.transparent": "#00000000", "border.disabled": borderSubtle,

            "elevated_surface.background": bg(p.surfaceHigh), "surface.background": bg(p.surface),
            background: transparent ? null : p.background,

            "element.background": p.surface, "element.hover": p.surfaceHigh,
            "element.active": alpha(p.overlay, "4d"), "element.selected": alpha(p.surfaceHigh, "4d"),
            "element.disabled": p.surface,
            "drop_target.background": alpha(p.overlay, "66"),
            "ghost_element.background": "#00000000", "ghost_element.hover": alpha(p.surfaceHigh, "4d"),
            "ghost_element.active": alpha(p.overlay, "99"), "ghost_element.selected": alpha(p.overlay, "66"),
            "ghost_element.disabled": p.overlay,

            text: p.text, "text.muted": p.subtext, "text.placeholder": p.overlay,
            "text.disabled": p.overlay, "text.accent": p.accent,
            icon: p.text, "icon.muted": p.subtext, "icon.disabled": p.overlay,
            "icon.placeholder": p.overlay, "icon.accent": p.accent,

            "status_bar.background": bg(p.surface), "title_bar.background": bg(p.surface),
            "title_bar.inactive_background": bg(p.surface), "toolbar.background": bg(p.background),
            "tab_bar.background": bg(p.surface), "tab.inactive_background": bg(p.surface), "tab.active_background": bg(p.background),
            "search.match_background": alpha(p.accent, "4d"), "search.active_match_background": alpha(p.danger, "4d"),

            "panel.background": bg(p.surface), "panel.focused_border": p.text,
            "panel.indent_guide": alpha(p.overlay, "99"), "panel.indent_guide_active": p.overlay,
            "panel.indent_guide_hover": p.accent, "panel.overlay_background": bg(p.surface),
            "pane.focused_border": p.text, "pane_group.border": borderColor,

            "scrollbar.thumb.background": alpha(p.overlay, "80"), "scrollbar.thumb.hover_background": p.overlay,
            "scrollbar.thumb.active_background": null, "scrollbar.thumb.border": null,
            "scrollbar.track.background": bg(p.surface), "scrollbar.track.border": alpha(p.text, "12"),
            "minimap.thumb.background": alpha(p.accent, "33"), "minimap.thumb.hover_background": alpha(p.accent, "66"),
            "minimap.thumb.active_background": alpha(p.accent, "99"), "minimap.thumb.border": null,

            "editor.foreground": p.text, "editor.background": bg(p.background), "editor.gutter.background": bg(p.background),
            "editor.subheader.background": bg(p.surface),
            "editor.active_line.background": alpha(p.text, "12"), "editor.highlighted_line.background": null,
            "editor.line_number": p.subtext, "editor.active_line_number": p.accent,
            "editor.invisible": alpha(p.overlay, "66"),
            "editor.wrap_guide": p.overlay, "editor.active_wrap_guide": p.overlay,
            "editor.document_highlight.bracket_background": alpha(p.accent, "17"),
            "editor.document_highlight.read_background": alpha(p.subtext, "29"),
            "editor.document_highlight.write_background": alpha(p.subtext, "29"),
            "editor.indent_guide": alpha(p.overlay, "99"), "editor.indent_guide_active": p.overlay,

            "terminal.background": bg(p.background), "terminal.ansi.background": bg(p.background),
            "terminal.foreground": p.text, "terminal.dim_foreground": p.subtext, "terminal.bright_foreground": p.text,
            "terminal.ansi.black": p.surfaceHigh, "terminal.ansi.white": p.subtext,
            "terminal.ansi.red": p.danger, "terminal.ansi.green": p.success, "terminal.ansi.yellow": p.warning,
            "terminal.ansi.blue": p.accent, "terminal.ansi.magenta": p.secondary, "terminal.ansi.cyan": p.tertiary,
            "terminal.ansi.bright_black": p.overlay, "terminal.ansi.bright_white": p.text,
            "terminal.ansi.bright_red": p.danger, "terminal.ansi.bright_green": p.success, "terminal.ansi.bright_yellow": p.warning,
            "terminal.ansi.bright_blue": p.accent, "terminal.ansi.bright_magenta": p.secondary, "terminal.ansi.bright_cyan": p.tertiary,
            "terminal.ansi.dim_black": p.surfaceHigh, "terminal.ansi.dim_white": p.subtext,
            "terminal.ansi.dim_red": p.danger, "terminal.ansi.dim_green": p.success, "terminal.ansi.dim_yellow": p.warning,
            "terminal.ansi.dim_blue": p.accent, "terminal.ansi.dim_magenta": p.secondary, "terminal.ansi.dim_cyan": p.tertiary,

            "link_text.hover": p.accent,

            "version_control.added": p.success, "version_control.deleted": p.danger,
            "version_control.modified": p.warning, "version_control.renamed": p.secondary,
            "version_control.conflict": p.warning,
            "version_control.conflict_marker.ours": alpha(p.success, "33"),
            "version_control.conflict_marker.theirs": alpha(p.accent, "33"),
            "version_control.ignored": p.subtext,

            "debugger.accent": p.danger,
            "editor.debugger_active_line.background": alpha(p.warning, "12"),

            players: [
                { cursor: p.accent, selection: alpha(p.accent, "4d"), background: p.accent },
                { cursor: p.secondary, selection: alpha(p.secondary, "4d"), background: p.secondary },
                { cursor: p.tertiary, selection: alpha(p.tertiary, "4d"), background: p.tertiary },
                { cursor: p.success, selection: alpha(p.success, "4d"), background: p.success },
                { cursor: p.warning, selection: alpha(p.warning, "4d"), background: p.warning },
                { cursor: p.danger, selection: alpha(p.danger, "4d"), background: p.danger }
            ],

            syntax: {
                variable: syn(txt), "variable.builtin": syn(err), "variable.parameter": syn(err),
                "variable.member": syn(fn), "variable.special": syn(err, "italic"),
                constant: syn(num), "constant.builtin": syn(num), "constant.macro": syn(txt),
                module: syn(num, "italic"), label: syn(doc),
                string: syn(str), "string.documentation": syn(doc), "string.regexp": syn(fn),
                "string.escape": syn(fn), "string.special": syn(fn), "string.special.path": syn(fn),
                "string.special.symbol": syn(err), "string.special.url": syn(txt, "italic"),
                character: syn(doc), "character.special": syn(fn),
                boolean: syn(num), number: syn(num), "number.float": syn(num),
                tag: syn(fn), "tag.attribute": syn(num, "italic"), "tag.delimiter": syn(doc),
                type: syn(num), "type.builtin": syn(kw, "italic"), "type.definition": syn(num),
                "type.interface": syn(num, "italic"), "type.super": syn(num, "italic"),
                attribute: syn(num), "selector.pseudo": syn(num),
                property: syn(fn), function: syn(fn), "function.builtin": syn(err),
                "function.call": syn(fn), "function.macro": syn(txt), "function.method": syn(fn),
                "function.method.call": syn(fn), constructor: syn(err),
                operator: syn(doc),
                keyword: syn(kw), "keyword.modifier": syn(kw), "keyword.type": syn(kw),
                "keyword.coroutine": syn(kw), "keyword.function": syn(kw), "keyword.operator": syn(kw),
                "keyword.import": syn(kw), "keyword.repeat": syn(kw), "keyword.return": syn(kw),
                "keyword.debug": syn(kw), "keyword.exception": syn(kw), "keyword.conditional": syn(kw),
                "keyword.conditional.ternary": syn(kw), "keyword.directive": syn(fn),
                "keyword.directive.define": syn(fn), "keyword.export": syn(kw),
                punctuation: syn(sub), "punctuation.delimiter": syn(sub), "punctuation.bracket": syn(sub),
                "punctuation.special": syn(fn), "punctuation.special.symbol": syn(err),
                "punctuation.list_marker": syn(doc),
                comment: syn(sub, "italic"), "comment.doc": syn(sub, "italic"), "comment.documentation": syn(sub, "italic"),
                "comment.info": syn(doc, "italic"), "comment.error": syn(err, "italic"),
                "comment.warning": syn(num, "italic"), "comment.warn": syn(num, "italic"),
                "comment.hint": syn(fn, "italic"), "comment.todo": syn(err, "italic"), "comment.note": syn(txt, "italic"),
                "diff.plus": syn(str), "diff.minus": syn(err),
                parameter: syn(err), field: syn(fn), namespace: syn(num, "italic"),
                float: syn(num), symbol: syn(err), "string.regex": syn(fn),
                text: syn(txt), "emphasis.strong": syn(txt, null, 700), emphasis: syn(txt, "italic"),
                embedded: syn(txt), "text.literal": syn(str), concept: syn(doc),
                enum: syn(doc, null, 700), "function.decorator": syn(num), "type.class.definition": syn(num, null, 700),
                hint: syn(sub, "italic"), link_text: syn(fn), link_uri: syn(fn, "italic"),
                parent: syn(num), predictive: syn(sub), predoc: syn(err), preproc: syn(fn),
                primary: syn(err), "tag.doctype": syn(kw), "string.doc": syn(doc, "italic"),
                title: syn(err, null, 800), variant: syn(err)
            }
        };

        // Quiet indicators (hidden/hint/predictive) sit on the panel
        // surface instead of a tint of their own color, so they read as
        // dimmed rather than as an active status.
        const statusColor = {
            conflict: p.warning, created: p.success, deleted: p.danger, error: p.danger,
            hidden: p.subtext, hint: p.tertiary, ignored: p.subtext, info: p.tertiary,
            modified: p.warning, predictive: p.subtext, renamed: p.secondary, success: p.success,
            unreachable: p.danger, warning: p.warning
        };
        const quiet = { hidden: true, hint: true, predictive: true };
        for (const key in statusColor) {
            const c = statusColor[key];
            style[key] = c;
            style[key + ".border"] = key === "predictive" ? p.accent : c;
            style[key + ".background"] = quiet[key] ? bg(p.surface) : alpha(c, "26");
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
