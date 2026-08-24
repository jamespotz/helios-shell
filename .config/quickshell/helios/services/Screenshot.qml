pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot service — captures via grim (fullscreen/region via slurp),
// copies to clipboard with wl-copy, and saves to ~/Pictures/Screenshots.
// Three modes: fullscreen, region (interactive slurp picker), active window
// (via hyprctl activewindow geometry).
QtObject {
    id: root

    readonly property string modeFullscreen: "fullscreen"
    readonly property string modeRegion: "region"
    readonly property string modeWindow: "window"

    property string mode: root.modeFullscreen
    property bool capturing: false
    property string lastPath: ""
    property string lastError: ""
    property bool lastCopied: false

    readonly property string outputDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    function capture(captureMode) {
        if (root.capturing) return;
        if (captureMode) root.mode = captureMode;
        root.capturing = true;
        root.lastError = "";
        root.lastCopied = false;

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

    function _shoot(geometry) {
        const ts = new Date();
        const pad = n => String(n).padStart(2, "0");
        const stamp = ts.getFullYear() + pad(ts.getMonth() + 1) + pad(ts.getDate())
            + "-" + pad(ts.getHours()) + pad(ts.getMinutes()) + pad(ts.getSeconds());
        root.lastPath = root.outputDir + "/screenshot-" + stamp + ".png";

        // Build grim command: grim [-g geometry] output | wl-copy && save
        let cmd = "mkdir -p '" + root.outputDir + "' && grim";
        if (geometry) cmd += " -g '" + geometry + "'";
        cmd += " '" + root.lastPath + "'";
        cmd += " && wl-copy < '" + root.lastPath + "'";

        grimProc.command = ["sh", "-c", cmd];
        grimProc.running = false;
        grimProc.running = true;
    }

    // slurp for region selection — same pattern as ScreenRecorder
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

    // grim capture + wl-copy
    property Process grimProc: Process {
        onExited: exitCode => {
            root.capturing = false;
            if (exitCode === 0) {
                root.lastCopied = true;
            } else {
                root.lastError = "Screenshot failed (exit " + exitCode + ")";
                root.lastPath = "";
            }
        }
    }

    property Process folderOpener: Process {}
    property Process fileOpener: Process {}
}
