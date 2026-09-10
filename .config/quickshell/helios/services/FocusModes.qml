pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Focus mode presets — each one is a snapshot of DND, caffeine (idle
// inhibit), power profile, night light, and a set of apps to launch,
// applied together through the services that already own each of those
// settings (Bridge, IdleInhibit, PowerProfiles, NightLight, AppLaunch).
// Persisted the same way LauncherIsland persists launch counts: a plain JSON
// FileView, since this is a user-editable list rather than a fixed schema
// (see launchCountsFile in LauncherIsland.qml for the identical pattern).
QtObject {
    id: root

    // preset: { id, name, icon, dnd, caffeine, nightLight, powerProfile
    // ("saver"|"balanced"|"performance"|""), apps: [string] }
    property var presets: [
        { id: "focus", name: "Focus", icon: "center_focus_strong", dnd: true, caffeine: true, nightLight: true, powerProfile: "", apps: [] }
    ]
    property string activeId: ""

    function save() { presetsFile.setText(JSON.stringify(root.presets)); }

    property FileView presetsFile: FileView {
        path: Quickshell.statePath("focus-presets.json")
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(presetsFile.text());
                if (Array.isArray(parsed) && parsed.length > 0) root.presets = parsed;
            } catch (e) {
                // First run — keep the built-in default above.
            }
        }
    }

    function _nextId() {
        return "focus-" + Date.now();
    }

    function addPreset() {
        const preset = { id: root._nextId(), name: "New Focus", icon: "center_focus_strong",
            dnd: true, caffeine: false, nightLight: false, powerProfile: "", apps: [] };
        root.presets = root.presets.concat([preset]);
        root.save();
        return preset;
    }

    function updatePreset(id, patch) {
        root.presets = root.presets.map(p => p.id === id ? Object.assign({}, p, patch) : p);
        root.save();
    }

    function removePreset(id) {
        root.presets = root.presets.filter(p => p.id !== id);
        if (root.activeId === id) root.activeId = "";
        root.save();
    }

    readonly property var _profileMap: ({
        saver: PowerProfile.PowerSaver,
        balanced: PowerProfile.Balanced,
        performance: PowerProfile.Performance
    })

    function apply(preset) {
        Bridge.dndEnabled = !!preset.dnd;
        if (IdleInhibit.inhibited !== !!preset.caffeine) IdleInhibit.toggleInhibit();
        NightLight.setEnabled(!!preset.nightLight);
        if (preset.powerProfile && root._profileMap[preset.powerProfile] !== undefined) {
            PowerProfiles.profile = root._profileMap[preset.powerProfile];
        }
        for (const app of (preset.apps || [])) {
            if (!AppLaunch.focusWindow(app, app)) {
                const entry = AppLaunch.resolveEntry(app, app);
                if (entry) AppLaunch.launch(entry);
            }
        }
        root.activeId = preset.id;
    }

    // Turns off what a preset would have turned on — doesn't try to restore
    // whatever the settings were before, since there's no prior snapshot
    // (same tradeoff a Do Not Disturb or Night Light toggle already makes).
    function deactivate() {
        Bridge.dndEnabled = false;
        if (IdleInhibit.inhibited) IdleInhibit.toggleInhibit();
        NightLight.setEnabled(false);
        PowerProfiles.profile = PowerProfile.Balanced;
        root.activeId = "";
    }

    function toggle(preset) {
        if (root.activeId === preset.id) root.deactivate();
        else root.apply(preset);
    }
}
