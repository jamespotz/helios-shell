pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Idle-pill pointer gestures (wheel, middle click, right click) and the
// fullscreen layer rule. Island.qml forwards raw input here; which action runs
// comes from Config (Settings > Island > Gestures).
QtObject {
    id: root

    readonly property var _sink: Pipewire.defaultAudioSink
    property PwObjectTracker _tracker: PwObjectTracker { objects: root._sink ? [root._sink] : [] }

    // One wheel notch is 120 units; touchpads send smaller deltas that add up.
    function _accumulate(rest, delta) {
        const total = rest + delta;
        const steps = Math.trunc(total / 120);
        return { steps: steps, rest: total - steps * 120 };
    }

    // Positive steps = wheel up: louder, or the previous workspace (matches
    // the Super+scroll binds).
    function scroll(steps) {
        if (steps === 0) return;
        if (Config.gestureScroll === "volume" && root._sink && root._sink.audio)
            root._sink.audio.volume = Math.max(0, Math.min(1, root._sink.audio.volume + steps * 0.05));
        else if (Config.gestureScroll === "workspace")
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"e" + (steps > 0 ? "-" : "+") + Math.abs(steps) + "\" })");
    }

    function middleClick() {
        if (Config.gestureMiddleClick === "playpause")
            MediaSession.togglePlaying();
        else if (Config.gestureMiddleClick === "mute" && root._sink && root._sink.audio)
            root._sink.audio.muted = !root._sink.audio.muted;
    }

    function rightClick(screenName) {
        if (Config.gestureRightClick !== "off")
            IslandNavigation.toggle(screenName, Config.gestureRightClick);
    }

    // Top-layer surfaces sit under a fullscreen window. With "alerts", an
    // alert card or open panel moves to Overlay; the idle pill and hover row
    // never do.
    function overFullscreen(option, hasFullscreen, mode) {
        return option === "alerts" && hasFullscreen && mode !== "idle" && mode !== "peek";
    }
}
