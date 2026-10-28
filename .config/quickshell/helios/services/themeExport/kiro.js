.pragma library
.import "vscode.js" as Vscode

// Kiro (Amazon's VS Code fork) uses the same User/settings.json shape and
// honors the same "workbench.colorCustomizations" key, so it reuses the
// VS Code builder and merge against its own config directory.

function exportTheme(p, ctx) {
    const path = ctx.home + "/.config/Kiro/User/settings.json";
    return { files: [{ path: path, text: Vscode.mergeVscodeSettings(ctx.read(path), Vscode.buildVscodeColors(p)) }] };
}
