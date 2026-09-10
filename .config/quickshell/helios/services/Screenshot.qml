pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot service — captures via grim (fullscreen/region via slurp),
// optionally OCRs the capture with tesseract, and optionally copies the
// result to the clipboard with wl-copy. Saves to outputDir either way.
QtObject {
    id: root

    readonly property string modeFullscreen: "fullscreen"
    readonly property string modeRegion: "region"
    readonly property string modeWindow: "window"

    property string mode: root.modeFullscreen
    property bool ocrEnabled: false
    property bool copyToClipboardEnabled: true
    property bool capturing: false
    property string lastPath: ""
    property string lastError: ""
    property bool lastCopied: false
    property string extractedText: ""

    // ponytail: session-only, resets on shell restart. Persist via
    // Bridge-style JsonAdapter if that's ever needed.
    property string outputDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    readonly property string _ocrTextPath: "/tmp/helios-screenshot-ocr.txt"

    function capture(captureMode) {
        if (root.capturing) return;
        if (captureMode) root.mode = captureMode;
        root.capturing = true;
        root.lastError = "";
        root.lastCopied = false;
        root.extractedText = "";

        if (root.mode === root.modeRegion) {
            regionPicker.running = false;
            regionPicker.running = true;
        } else if (root.mode === root.modeWindow) {
            windowGeometry.running = false;
            windowGeometry.running = true;
        } else {
            root._shoot("");
        }
    }

    function captureFullscreen() { root.capture(root.modeFullscreen) }
    function captureRegion() { root.capture(root.modeRegion) }
    function captureWindow() { root.capture(root.modeWindow) }

    // Re-copy the last result on demand (the "Copy" chip after a capture).
    function copyLast() {
        if (!root.lastPath) return;
        clipboardProc.command = ["sh", "-c",
            root.ocrEnabled && root.extractedText.length > 0
                ? "wl-copy < '" + root._ocrTextPath + "'"
                : "wl-copy < '" + root.lastPath + "'"];
        clipboardProc.running = false;
        clipboardProc.running = true;
    }

    function chooseOutputDir() {
        IslandNavigation.close();
        dirPicker.running = true;
    }

    function openFolder() {
        folderOpener.command = ["xdg-open", root.outputDir];
        folderOpener.running = true;
    }

    function openLast() {
        if (root.lastPath) {
            fileOpener.command = ["xdg-open", root.lastPath];
            fileOpener.running = true;
        }
    }

    // Clears the result if lastPath was deleted out from under us (e.g. the
    // user removed it in a file manager) — checked when the island reopens
    // rather than watched continuously.
    function verifyLastPath() {
        if (!root.lastPath) return;
        existsCheck.command = ["test", "-f", root.lastPath];
        existsCheck.running = false;
        existsCheck.running = true;
    }

    function _shoot(geometry) {
        const ts = new Date();
        const pad = n => String(n).padStart(2, "0");
        const stamp = ts.getFullYear() + pad(ts.getMonth() + 1) + pad(ts.getDate())
            + "-" + pad(ts.getHours()) + pad(ts.getMinutes()) + pad(ts.getSeconds());
        root.lastPath = root.outputDir + "/Screen-" + stamp + ".png";

        let cmd = "set -o pipefail; mkdir -p '" + root.outputDir + "' && grim";
        if (geometry) cmd += " -g '" + geometry + "'";
        cmd += " '" + root.lastPath + "'";
        if (root.ocrEnabled) {
            cmd += " && tesseract '" + root.lastPath + "' - -l eng 2>/dev/null > '" + root._ocrTextPath + "'";
        }
        if (root.copyToClipboardEnabled) {
            cmd += root.ocrEnabled
                ? " && wl-copy < '" + root._ocrTextPath + "'"
                : " && wl-copy < '" + root.lastPath + "'";
        }

        grimProc.command = ["sh", "-c", cmd];
        grimProc.running = false;
        grimProc.running = true;
    }

    // slurp for region selection
    property Process regionPicker: Process {
        property string geometry: ""
        command: ["sh", "-c", "exec slurp < /dev/null"]
        stdout: SplitParser {
            onRead: line => regionPicker.geometry = line.trim()
        }
        onExited: exitCode => {
            if (exitCode === 0 && regionPicker.geometry.length > 0) {
                root._shoot(regionPicker.geometry);
            } else {
                root.capturing = false;
            }
            regionPicker.geometry = "";
        }
    }

    // Get active window geometry via hyprctl
    property Process windowGeometry: Process {
        property string geometry: ""
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"'"]
        stdout: SplitParser {
            onRead: line => windowGeometry.geometry = line.trim()
        }
        onExited: exitCode => {
            if (exitCode === 0 && windowGeometry.geometry.length > 0) {
                root._shoot(windowGeometry.geometry);
            } else {
                root.capturing = false;
                root.lastError = "Could not get active window geometry";
            }
            windowGeometry.geometry = "";
        }
    }

    // grim capture, optional tesseract OCR, optional wl-copy — all one shot
    property Process grimProc: Process {
        onExited: exitCode => {
            root.capturing = false;
            if (exitCode === 0) {
                root.lastCopied = true;
                if (root.ocrEnabled) ocrTextReader.running = true;
            } else {
                root.lastError = "Screenshot failed (exit " + exitCode + ")";
                root.lastPath = "";
            }
        }
    }

    property Process ocrTextReader: Process {
        command: ["cat", root._ocrTextPath]
        stdout: StdioCollector {
            onStreamFinished: root.extractedText = text.trim()
        }
    }

    property Process dirPicker: Process {
        command: ["zenity", "--file-selection", "--directory", "--title=Choose screenshot folder"]
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = text.trim();
                if (picked) root.outputDir = picked;
            }
        }
    }

    property Process existsCheck: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastPath = "";
                root.extractedText = "";
                root.lastCopied = false;
            }
        }
    }

    property Process clipboardProc: Process {}
    property Process folderOpener: Process {}
    property Process fileOpener: Process {}
}
