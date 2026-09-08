pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot service — captures via grim (fullscreen/region via slurp),
// copies to clipboard with wl-copy, and saves to ~/Pictures/Screenshots.
// Three modes: fullscreen, region (interactive slurp picker), active window
// (via hyprctl activewindow geometry).
//
// OCR reuses the region-capture pipeline: same grim+slurp geometry, but pipes
// the image through tesseract and copies the extracted text instead of the
// image itself. purpose distinguishes the two post-processing paths.
QtObject {
    id: root

    readonly property string modeFullscreen: "fullscreen"
    readonly property string modeRegion: "region"
    readonly property string modeWindow: "window"

    readonly property string purposeImage: "image"
    readonly property string purposeOcr: "ocr"

    property string mode: root.modeFullscreen
    property string purpose: root.purposeImage
    property bool capturing: false
    property string lastPath: ""
    property string lastError: ""
    property bool lastCopied: false

    readonly property string outputDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    function capture(captureMode, capturePurpose) {
        if (root.capturing) return;
        if (captureMode) root.mode = captureMode;
        root.purpose = capturePurpose || root.purposeImage;
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

    // OCR the selected region: extract text via tesseract, copy text to
    // clipboard instead of the image. Region only — that's the useful case
    // (pick the text you want); fullscreen/window OCR isn't asked for.
    function captureOcrRegion() { root.capture(root.modeRegion, root.purposeOcr) }

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

        // Build grim command: grim [-g geometry] output, then either
        // wl-copy the image (purposeImage) or OCR it and wl-copy the text
        // (purposeOcr). set -o pipefail so a tesseract failure in the OCR
        // pipe still surfaces as a non-zero exit.
        let cmd = "set -o pipefail; mkdir -p '" + root.outputDir + "' && grim";
        if (geometry) cmd += " -g '" + geometry + "'";
        cmd += " '" + root.lastPath + "'";
        cmd += root.purpose === root.purposeOcr
            ? " && tesseract '" + root.lastPath + "' - -l eng 2>/dev/null | wl-copy"
            : " && wl-copy < '" + root.lastPath + "'";

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
                root.lastError = root.purpose === root.purposeOcr
                    ? "OCR failed (exit " + exitCode + ")"
                    : "Screenshot failed (exit " + exitCode + ")";
                root.lastPath = "";
            }
        }
    }

    property Process folderOpener: Process {}
    property Process fileOpener: Process {}
}
