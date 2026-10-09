pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot service — captures via grim (fullscreen/region via slurp) and
// optionally copies the result to the clipboard with wl-copy. Text mode picks
// a region, OCRs it with tesseract, and always copies the extracted text.
// Saves to outputDir either way.
QtObject {
    id: root

    readonly property string modeFullscreen: "fullscreen"
    readonly property string modeRegion: "region"
    readonly property string modeWindow: "window"
    readonly property string modeText: "text"

    property string mode: root.modeFullscreen
    property bool copyToClipboardEnabled: true
    property bool capturing: false
    property string lastPath: ""
    property string lastError: ""
    property bool lastCopied: false
    property string extractedText: ""
    property bool _lastCaptureWasText: false
    // Geometry ("x,y wxh", layout coordinates) of the last capture; empty
    // means every output.
    property string lastGeometry: ""

    // Fires with the shutter sound so CaptureFlash can flash the area.
    signal captured(string geometry)

    // ponytail: session-only, resets on shell restart. Persist via
    // ShellState-style JsonAdapter if that's ever needed.
    property string outputDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    function capture(captureMode) {
        if (root.capturing) return;
        if (captureMode) root.mode = captureMode;
        root.capturing = true;
        root.lastError = "";
        root.lastCopied = false;
        root.extractedText = "";

        if (root.mode === root.modeRegion || root.mode === root.modeText) {
            regionPicker.running = false;
            regionPicker.running = true;
        } else if (root.mode === root.modeWindow) {
            windowGeometry.running = false;
            windowGeometry.running = true;
        } else {
            if (IslandNavigation.open && IslandNavigation.destinationId === "screenshot") {
                IslandNavigation.close();
                fullscreenDelay.restart();
            } else {
                root._shoot("");
            }
        }
    }

    function captureFullscreen() { root.capture(root.modeFullscreen) }
    function captureRegion() { root.capture(root.modeRegion) }
    function captureWindow() { root.capture(root.modeWindow) }
    function captureText() { root.capture(root.modeText) }

    property Timer fullscreenDelay: Timer {
        interval: 200
        repeat: false
        onTriggered: root._shoot("")
    }

    // Re-copy the last result on demand (the "Copy" chip after a capture).
    function copyLast() {
        if (!root.lastPath) return;
        root.lastCopied = false;
        clipboardProc.command = root._lastCaptureWasText
            ? ["wl-copy"] : ["sh", "-c", "wl-copy < \"$1\"", "_", root.lastPath];
        clipboardProc.stdinEnabled = root._lastCaptureWasText;
        clipboardProc.running = false;
        clipboardProc.running = true;
    }

    function chooseOutputDir() {
        IslandNavigation.close();
        dirPicker.running = true;
    }

    // setsid + redirecting all stdio to /dev/null fully detaches the opened
    // app from this Process: without it, some apps' own child processes
    // (e.g. an image viewer that logs to stdout) inherit our still-open
    // pipe, and once xdg-open itself exits and Quickshell closes that pipe,
    // the still-running app's next write to it dies with EPIPE.
    function openFolder() {
        folderOpener.command = ["sh", "-c", "setsid xdg-open \"$0\" >/dev/null 2>&1 </dev/null &", root.outputDir];
        folderOpener.running = true;
    }

    function openLast() {
        if (root.lastPath) {
            fileOpener.command = ["sh", "-c", "setsid xdg-open \"$0\" >/dev/null 2>&1 </dev/null &", root.lastPath];
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
        root._lastCaptureWasText = root.mode === root.modeText;
        const ts = new Date();
        const pad = n => String(n).padStart(2, "0");
        const stamp = ts.getFullYear() + pad(ts.getMonth() + 1) + pad(ts.getDate())
            + "-" + pad(ts.getHours()) + pad(ts.getMinutes()) + pad(ts.getSeconds());
        root.lastPath = root.outputDir + "/Screen-" + stamp + ".png";
        root.lastGeometry = geometry;

        // Paths go in as positional args, never spliced into the script, so
        // a picked folder like "Bob's Shots" can't break or inject the command.
        // $1 outputDir, $2 lastPath, $3 geometry.
        let cmd = "set -o pipefail; mkdir -p \"$1\" && grim";
        if (geometry) cmd += " -g \"$3\"";
        cmd += " \"$2\"";
        if (root.mode === root.modeText)
            cmd += " && tesseract \"$2\" - -l eng 2>/dev/null";
        else if (root.copyToClipboardEnabled)
            cmd += " && wl-copy < \"$2\"";

        grimProc.command = ["sh", "-c", cmd, "_", root.outputDir, root.lastPath, geometry];
        grimProc.running = false;
        grimProc.running = true;
    }

    function _captureSucceeded() {
        root.capturing = false;
        root.lastCopied = true;
        if (root._lastCaptureWasText) { root.lastCopied = false; root.copyLast(); }

        const fileName = root.lastPath.split("/").pop();
        notificationProc.command = ["notify-send", "--app-name=Helios", "--icon=camera-photo",
            "Screenshot taken", fileName];
        notificationProc.running = true;
        soundProc.command = ["canberra-gtk-play", "--id=screen-capture"];
        soundProc.running = true;
        root.captured(root.lastGeometry);
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

    // grim capture, tesseract OCR in text mode, optional wl-copy — all one shot
    property Process grimProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lastCaptureWasText) root.extractedText = text;
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root._captureSucceeded();
            } else {
                root.capturing = false;
                root.lastError = "Screenshot failed (exit " + exitCode + ")";
                root.lastPath = "";
            }
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

    property Process clipboardProc: Process {
        onStarted: {
            if (stdinEnabled) {
                write(root.extractedText);
                stdinEnabled = false;
            }
        }
        onExited: exitCode => { root.lastCopied = exitCode === 0; }
    }
    property Process folderOpener: Process {}
    property Process fileOpener: Process {}
    property Process notificationProc: Process {}
    property Process soundProc: Process {}
}
