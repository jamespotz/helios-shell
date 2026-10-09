import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    readonly property Process terminator: Process {
        command: ["sh", "-c", 'kill -TERM "$PPID"']
    }
    readonly property Timer terminateDelay: Timer {
        interval: 50
        onTriggered: root.terminator.running = true
    }
    Component.onCompleted: {
        try {
            const colors = JSON.parse(ThemeExportVscode.mergeVscodeSettings('{"workbench.colorCustomizations":{"[Dark]":{"old":true}},"keep":true}', {fresh:true}));
            if (!colors.keep || !colors["workbench.colorCustomizations"].fresh) throw new Error("VS Code merge");
            const settings = JSON.parse(ThemeExportZed.mergeZedSettings('{"theme":{}}', true));
            if (settings.theme.mode !== "dark" || settings.theme.dark !== "Helios") throw new Error("Zed merge");
            console.warn("THEME_EXPORT_AUDIT_TEST_PASS");
        } catch (error) {
            console.warn("THEME_EXPORT_AUDIT_TEST_FAIL", error);
        }
        root.terminateDelay.start();
    }
}
