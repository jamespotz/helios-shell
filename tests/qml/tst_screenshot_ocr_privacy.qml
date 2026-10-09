import QtQuick
import Quickshell
import Quickshell.Io
import services
ShellRoot {
    id: root
    property int phase: 0
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    Component.onCompleted: { Screenshot.outputDir = Quickshell.env("OCR_PRIVACY_TEST_ROOT") + "/captures"; Screenshot.captureText(); }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (Screenshot.capturing || !Screenshot.lastCopied) return;
            if (Quickshell.env("OCR_PRIVACY_EMPTY") === "1" && Screenshot.extractedText !== "") { console.error("OCR_PRIVACY_TEST_FAIL empty OCR"); root.terminator.running = true; stop(); return; }
            if (root.phase === 0) { root.phase++; Screenshot.copyLast(); return; }
            console.warn("OCR_PRIVACY_TEST_PASS"); root.terminator.running = true; stop();
        }
    }
}
