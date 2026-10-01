pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Neovim
QtObject {
    id: root

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
            + "  vim.o.background = '" + (Themes.isDark(p.background) ? "dark" : "light") + "'\n"
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
}
