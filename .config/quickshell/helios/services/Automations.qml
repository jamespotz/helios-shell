pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Simple trigger/action rules — each one watches a state this shell
// already tracks and calls straight into the service that owns the
// resulting action (Bridge, DisplaySettings, PowerProfiles). Not a
// generic automation DSL: exactly the four concrete rules asked for, each
// off by default since auto-acting on a device/battery event is the kind
// of thing that should be opt-in. The fourth ("meeting starts → DND") is
// already covered by Calendar.qml's meetingFocusId — that's a Focus Modes
// concern with its own picker in CalendarTab.qml, not duplicated here.
QtObject {
    id: root

    property bool headphonesRule: false
    property bool monitorRule: false
    property bool batteryRule: false

    function setHeadphonesRule(v) { root.headphonesRule = v; root._save(); }
    function setMonitorRule(v) { root.monitorRule = v; root._save(); }
    function setBatteryRule(v) { root.batteryRule = v; root._save(); if (v) root._checkBattery(); }

    function _save() {
        settingsFile.setText(JSON.stringify({ headphones: root.headphonesRule, monitor: root.monitorRule, battery: root.batteryRule }));
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("automation-rules.json")
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(settingsFile.text());
                if (parsed) {
                    root.headphonesRule = !!parsed.headphones;
                    root.monitorRule = !!parsed.monitor;
                    root.batteryRule = !!parsed.battery;
                }
            } catch (e) {
                // First run — rules stay off until explicitly enabled.
            }
        }
    }

    // ─── Rule: headphones connect → open media controls ──────────────────
    function _looksLikeHeadphones(dev) {
        const raw = (dev.icon || "").toLowerCase();
        return raw.includes("headset") || raw.includes("headphone");
    }

    readonly property var connectedHeadphoneIds: Bluetooth.state.devices
        .filter(d => d.connected && root._looksLikeHeadphones(d))
        .map(d => d.id)
    property var _prevHeadphoneIds: []
    property bool _headphonesReady: false

    onConnectedHeadphoneIdsChanged: {
        if (!root._headphonesReady) { root._prevHeadphoneIds = root.connectedHeadphoneIds; return; }
        const added = root.connectedHeadphoneIds.filter(id => !root._prevHeadphoneIds.includes(id));
        root._prevHeadphoneIds = root.connectedHeadphoneIds;
        if (added.length === 0 || !root.headphonesRule) return;
        const screen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        if (screen) IslandNavigation.toggle(screen, "media");
    }

    // ─── Rule: external monitor connects → restore its last layout ───────
    // Snapshots resolution/scale/transform/VRR per monitor name on every
    // poll; when a name that had disappeared comes back, replays its last
    // snapshot through DisplaySettings' own hyprctl-keyword functions
    // (same commands DisplaySettings.qml's UI calls) rather than a second
    // hyprctl-invoking implementation.
    property var monitorConfigs: ({})
    property var knownScreenNames: []

    property Timer monitorPollTimer: Timer {
        interval: 15000
        running: root.monitorRule
        repeat: true
        triggeredOnStart: true
        onTriggered: monitorPollProc.running = true
    }

    property Process monitorPollProc: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    const currentNames = list.map(m => m.name);
                    const added = currentNames.filter(n => !root.knownScreenNames.includes(n));

                    if (root.monitorRule) {
                        for (const name of added) {
                            const saved = root.monitorConfigs[name];
                            if (saved) root._restoreMonitor(name, saved);
                        }
                    }

                    const cfgs = Object.assign({}, root.monitorConfigs);
                    for (const m of list) {
                        cfgs[m.name] = { width: m.width, height: m.height, refreshRate: Math.round(m.refreshRate), scale: m.scale, transform: m.transform, vrr: m.vrr ? 1 : 0 };
                    }
                    root.monitorConfigs = cfgs;
                    root.knownScreenNames = currentNames;
                    monitorConfigsFile.setText(JSON.stringify(cfgs));
                } catch (e) {
                    // Skip this poll — next one 15s later just retries.
                }
            }
        }
    }

    function _restoreMonitor(name, cfg) {
        DisplaySettings.setResolution(name, cfg.width, cfg.height, cfg.refreshRate);
        DisplaySettings.setScale(name, cfg.scale);
        DisplaySettings.setTransform(name, cfg.transform);
        DisplaySettings.setVrr(name, cfg.vrr);
    }

    property FileView monitorConfigsFile: FileView {
        path: Quickshell.statePath("automation-monitor-configs.json")
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(monitorConfigsFile.text());
                if (parsed) root.monitorConfigs = parsed;
            } catch (e) {
                // First run — no saved layouts yet.
            }
        }
    }

    // ─── Rule: battery below 20% → enable Power Saver ─────────────────────
    readonly property var _batteryDevice: UPower.displayDevice
    readonly property bool _hasBattery: !!root._batteryDevice && root._batteryDevice.isLaptopBattery && root._batteryDevice.isPresent
    readonly property real batteryPercent: root._hasBattery ? root._batteryDevice.percentage * 100 : 100
    property bool _batteryLow: false

    function _checkBattery() {
        if (!root.batteryRule || !root._hasBattery) return;
        if (root.batteryPercent <= 20 && !root._batteryLow) {
            root._batteryLow = true;
            PowerProfiles.profile = PowerProfile.PowerSaver;
        } else if (root.batteryPercent > 30 && root._batteryLow) {
            root._batteryLow = false;
        }
    }

    onBatteryPercentChanged: root._checkBattery()

    Component.onCompleted: root._headphonesReady = true
}
