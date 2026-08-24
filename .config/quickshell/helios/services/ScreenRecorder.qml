pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Drives gpu-screen-recorder for the island's screen-recording tab. One
// process at a time: start writes an mp4 into ~/Videos/Recordings, stop
// sends SIGINT (not just running=false) so gsr finalizes the container
// instead of leaving a broken/unplayable file behind.
//
// Three capture modes map onto gsr's actual `-w` sources rather than
// anything invented — there is no per-window capture on a wlroots
// compositor, so "Window/App Specific" hands off to the xdg-desktop-portal
// picker (-w portal), which is what every other Wayland recorder does too.
QtObject {
    id: root

    readonly property string modeFullscreen: "fullscreen"
    readonly property string modeWindow: "window"
    readonly property string modeRegion: "region"

    property string mode: root.modeFullscreen
    property bool recording: false
    property bool starting: false
    property int elapsedSeconds: 0
    property string lastOutputPath: ""

    property string monitor: "screen"
    property bool captureAudio: true
    property string quality: "very_high"

    readonly property string outputDir: Quickshell.env("HOME") + "/Videos/Recordings"
    readonly property string elapsedLabel: {
        const m = Math.floor(root.elapsedSeconds / 60);
        const s = root.elapsedSeconds % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function setMode(m) {
        if (m === root.modeFullscreen || m === root.modeWindow || m === root.modeRegion) root.mode = m;
    }

    function start(monitorName) {
        if (root.recording || root.starting) return;
        if (monitorName) root.monitor = monitorName;
        root.starting = true;

        // The island tab closes itself (Bridge.closeIsland()) right before
        // calling this, to hand the pointer/keyboard grab it was holding
        // (Bar.qml's HyprlandFocusGrab, "click outside closes it") back to
        // Hyprland before slurp/the portal try to claim it — closing the
        // island alone wasn't enough; the release needed a real event-loop
        // turn to actually reach the compositor before the picker spawned,
        // or the picker's own grab request lost the race and it never got
        // input. This short deferral guarantees that gap regardless of who
        // called start() (button click or the `recorder` IPC).
        startDelay.restart();
    }

    property Timer startDelay: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            if (root.mode === root.modeRegion) {
                // Force a real off->on edge instead of trusting `running`'s
                // current value: if a previous slurp somehow exited without
                // this ever seeing it (leaving `running` desynced at true),
                // assigning `true` again is a silent no-op — nothing spawns,
                // nothing errors, and it looks exactly like "the button does
                // nothing" until the whole shell gets restarted. Explicitly
                // dropping it first makes every start() a guaranteed fresh
                // spawn no matter what state it was left in.
                regionPicker.running = false;
                regionPicker.running = true;
                return;
            }
            root._begin(root.mode === root.modeWindow ? "portal" : root.monitor);
        }
    }

    function stop() {
        if (!root.recording) return;
        proc.signal(2); // SIGINT
    }

    function toggle(monitorName) {
        if (root.recording) root.stop();
        else root.start(monitorName);
    }

    function openFolder() {
        folderOpener.command = ["xdg-open", root.outputDir];
        folderOpener.running = true;
    }

    // `source` is whatever gsr's -w flag takes directly: a monitor name,
    // "portal", or (for custom-area) a "WxHX+Y" geometry string — gsr's
    // separate `-w region -region WxH+X+Y` pairing is deprecated on current
    // versions and was also silently mis-sizing the capture, so the region
    // geometry gets passed straight as the -w value instead.
    function _begin(source) {
        const ts = new Date();
        const pad = n => String(n).padStart(2, "0");
        const stamp = ts.getFullYear() + pad(ts.getMonth() + 1) + pad(ts.getDate())
            + "-" + pad(ts.getHours()) + pad(ts.getMinutes()) + pad(ts.getSeconds());
        root.lastOutputPath = root.outputDir + "/recording-" + stamp + ".mp4";

        const args = ["gpu-screen-recorder", "-w", source, "-q", root.quality];
        if (root.captureAudio) args.push("-a", "default_output");
        args.push("-o", root.lastOutputPath);

        proc.command = ["sh", "-c", "mkdir -p '" + root.outputDir + "' && exec \"$@\"", "_"].concat(args);
        proc.running = false;
        proc.running = true;
    }

    // slurp draws the crosshair/rectangle picker. -f forces its output into
    // gsr's "WxH+X+Y" geometry shape directly — slurp's own default format
    // is "X,Y WxH", which gsr's -w does not accept, and was silently
    // producing a garbage/mis-sized capture region before this. Exits
    // non-zero with nothing printed if the user hits Escape instead, which
    // is why start() can't just always run gsr and needs this intermediate
    // step for region mode.
    //
    // The explicit "< /dev/null" is load-bearing: Quickshell's Process gives
    // its child an open, never-closed stdin pipe (so QML can write() to it
    // later), and slurp's own docs say non-TTY stdin makes it try to read
    // predefined rectangles from stdin instead of drawing the interactive
    // picker — confirmed via strace, it was blocking forever in read(0, ...),
    // never even creating its overlay surface. Redirecting from /dev/null
    // gives it an immediate EOF (zero predefined rects) so it falls through
    // to the normal interactive click-and-drag UI instead.
    property Process regionPicker: Process {
        id: regionPicker
        command: ["sh", "-c", "exec slurp -f \"%wx%h+%x+%y\" < /dev/null"]
        property string geometry: ""
        stdout: SplitParser {
            onRead: line => regionPicker.geometry = line
        }
        onExited: exitCode => {
            if (exitCode === 0 && regionPicker.geometry.length > 0) root._begin(regionPicker.geometry);
            else root.starting = false;
            regionPicker.geometry = "";
        }
    }

    property Process proc: Process {
        onStarted: {
            root.starting = false;
            root.recording = true;
            root.elapsedSeconds = 0;
            elapsedTimer.start();
        }
        onExited: {
            root.starting = false;
            root.recording = false;
            elapsedTimer.stop();
        }
    }

    property Timer elapsedTimer: Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        onTriggered: root.elapsedSeconds += 1
    }

    property Process folderOpener: Process {}
}
