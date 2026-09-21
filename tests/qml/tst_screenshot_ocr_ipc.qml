import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process resultWriter: Process {}

    Component.onCompleted: {
        Screenshot.ocrEnabled = false;
        Screenshot.copyToClipboardEnabled = false;
        Screenshot.captureOcrRegion();
        root.resultWriter.command = ["sh", "-c", "printf '%s' \"$1\" > \"$0\"; kill -TERM $PPID",
            Quickshell.env("OCR_IPC_TEST_RESULT"),
            Screenshot.mode + ":" + Screenshot.ocrEnabled + ":"
                + Screenshot.copyToClipboardEnabled + ":" + Screenshot.capturing];
        root.resultWriter.running = true;
    }
}
