pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Kiro (Amazon's VS Code fork) uses the same User/settings.json shape and
// honors the same "workbench.colorCustomizations" key, so it just reuses
// ThemeVscode's builder/merger against its own config directory.
QtObject {
    id: root

    function writeKiroTheme(p) {
        kiroSettingsFile.path = Quickshell.env("HOME") + "/.config/Kiro/User/settings.json";
        kiroSettingsFile.setText(ThemeVscode.mergeVscodeSettings(kiroSettingsFile.text(), ThemeVscode.buildVscodeColors(p)));
    }

    property FileView kiroSettingsFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
}
