pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Equalizer state for MediaCard's EasyEffects-backed EQ widget. Lives in a
// singleton (not on MediaCard's root Item) so the band values and selected
// preset survive the island closing and reopening — PanelWrapper's Loader
// destroys and recreates MediaCard every time the island tab is switched
// away from and back to "media". Deliberately in-memory only (no
// FileView/JsonAdapter persistence): the EQ is meant to reset to its
// default preset on shell startup, only surviving within a running session.
QtObject {
    id: root

    readonly property string eqScriptPath: Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/easyeffects-eq.py"
    readonly property var eqBandLabels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property var eqPresets: ({
        flat:    [0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50],
        bass:    [0.90, 0.85, 0.75, 0.65, 0.55, 0.45, 0.40, 0.35, 0.30, 0.30],
        pop:     [0.40, 0.45, 0.55, 0.65, 0.70, 0.65, 0.55, 0.50, 0.50, 0.55],
        rock:    [0.70, 0.65, 0.50, 0.40, 0.45, 0.55, 0.65, 0.70, 0.70, 0.65],
        treble:  [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.75, 0.85, 0.90, 0.90],
        vocal:   [0.35, 0.40, 0.50, 0.65, 0.75, 0.75, 0.65, 0.50, 0.45, 0.40],
        jazz:    [0.55, 0.50, 0.45, 0.50, 0.60, 0.60, 0.50, 0.45, 0.50, 0.55],
        classic: [0.50, 0.50, 0.50, 0.55, 0.55, 0.50, 0.50, 0.50, 0.55, 0.60]
    })
    property string currentPreset: "treble"
    property var eqValues: eqPresets["treble"].slice()
    property bool presetsReady: false
    property string pendingAction: ""
    property string pendingPreset: ""

    readonly property bool eqIsSaved: {
        const p = eqValues, preset = eqPresets[currentPreset];
        if (!preset) return false;
        for (let i = 0; i < preset.length; i++) {
            if (Math.abs(preset[i] - p[i]) > 0.001) return false;
        }
        return true;
    }

    function applyPreset(name) {
        root.currentPreset = name;
        root.eqValues = root.eqPresets[name].slice();
        if (!root.presetsReady) {
            root.pendingAction = "preset";
            root.pendingPreset = name;
            root.ensurePresets();
            return;
        }
        root._loadPreset(name);
    }

    function _loadPreset(name) {
        const presetName = name.charAt(0).toUpperCase() + name.slice(1);
        eqLoadPresetProc.command = ["flatpak", "run", "com.github.wwmm.easyeffects", "--load-preset", presetName];
        eqLoadPresetProc.running = true;
    }

    // One of these per band-drag release, not per drag frame — each call
    // shells out to `flatpak run`, too slow to fire continuously.
    function applyLiveBands() {
        if (!root.presetsReady) {
            root.pendingAction = "live";
            root.ensurePresets();
            return;
        }
        root._applyLiveBands();
    }

    function _applyLiveBands() {
        const args = root.eqValues.map(v => String((v - 0.5) * 24));
        eqLiveApplyProc.command = ["python3", root.eqScriptPath].concat(args);
        eqLiveApplyProc.running = true;
    }

    function ensurePresets() {
        if (!root.presetsReady && !ensurePresetsProc.running)
            ensurePresetsProc.running = true;
    }

    property Process eqLoadPresetProc: Process {}
    property Process eqLiveApplyProc: Process {}
    property Process ensurePresetsProc: Process {
        command: ["python3", root.eqScriptPath, "--ensure-presets"]
        onExited: exitCode => {
            if (exitCode !== 0) return;
            root.presetsReady = true;
            const action = root.pendingAction;
            root.pendingAction = "";
            if (action === "preset") root._loadPreset(root.pendingPreset);
            else if (action === "live") root._applyLiveBands();
        }
    }

    Component.onCompleted: root.ensurePresets()
}
