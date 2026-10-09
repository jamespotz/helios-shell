pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    readonly property var state: core.state
    readonly property bool active: state.status !== "idle"
    readonly property bool completionPending: state.completionPending && !root._saving && !root._saveFailed
    readonly property double remainingMs: core.remainingMs
    readonly property string remainingText: {
        const seconds = Math.ceil(remainingMs / 1000);
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
    signal completed()
    property string error: ""
    property bool _restoring: true
    property bool _saving: false
    property bool _saveFailed: false
    property FocusTimerCore core: FocusTimerCore {
        onStateChanged: if (!root._restoring) root._save()
        onCompleted: (kind, nextBreak) => {
            if (kind === "focus" && nextBreak)
                core.start(root.breakMinutes(nextBreak), "", typeof nextBreak === "number" ? "custom-break" : nextBreak + "-break");
            root.completed();
        }
    }
    property FileView stateFile: FileView {
        path: Quickshell.statePath("focus-timer.json")
        preload: true
        blockLoading: true
        atomicWrites: true
        blockWrites: true
        printErrors: false
        onLoaded: {
            root._restoring = true;
            try { core.nowMs = Date.now(); core.restore(JSON.parse(text())); } catch (e) { core.stop(); }
            root._restoring = false;
            root._save();
        }
        onLoadFailed: { root._restoring = false; }
        onSaved: { root._saving = false; root._saveFailed = false; root.error = ""; }
        onSaveFailed: { root._saving = false; root._saveFailed = true; root.error = qsTr("Could not save the Focus timer"); }
    }
    function _save() {
        const serialized = JSON.stringify(core.state);
        if (stateFile.text() === serialized) { root._saving = false; return; }
        root._saving = true;
        stateFile.setText(serialized);
    }
    function updateTime() { core.nowMs = Date.now(); core.tick(); }
    function start(minutes, presetId, customBreak) {
        updateTime();
        if (!core.start(minutes, presetId, "focus", customBreak || (minutes === 25 ? "short" : minutes === 50 ? "long" : minutes === 90 ? "extended" : ""))) return false;
        const preset = FocusModes.presets.find(p => p.id === presetId);
        if (preset) FocusModes.apply(preset);
        return true;
    }
    function startCustom(minutes, breakMinutes, presetId) {
        if (!Number.isInteger(minutes) || minutes < 1 || minutes > 180
            || !Number.isInteger(breakMinutes) || breakMinutes < 1 || breakMinutes > 60) return false;
        return root.start(minutes, presetId, breakMinutes);
    }
    function breakMinutes(type) {
        if (typeof type === "number") return type;
        return type === "short" ? Config.shortBreakMinutes : type === "long" ? Config.longBreakMinutes : Config.extendedBreakMinutes;
    }
    function startBreak(type) {
        if (!["short", "long", "extended"].includes(type)) return false;
        updateTime();
        return core.start(root.breakMinutes(type), "", type + "-break");
    }
    function pause() { updateTime(); return core.pause(); }
    function resume() { updateTime(); return core.resume(); }
    function extend(minutes) { updateTime(); return core.extend(minutes); }
    function stop() { core.stop(); }
    function dismissCompletion() { core.dismissCompletion(); }
    Component.onCompleted: stateFile.text()
    property Timer ticker: Timer { interval: 1000; repeat: true; running: root.state.status === "running"; onTriggered: root.updateTime() }
}
