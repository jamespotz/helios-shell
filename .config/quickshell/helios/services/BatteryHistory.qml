pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Rolling battery-percentage history. UPower already tracks battery state
// live (same UPower.displayDevice API modules/bar/StatusIndicators.qml
// uses for the status-bar icon) — no need to shell out to psutil for it.
// Persisted with the same FileView pattern services/Activity.qml uses for
// its usage log, so history survives a shell restart. On hardware with no
// battery (a desktop: UPower.displayDevice.isPresent is false), `available`
// stays false, the sample timer never runs, and `samples` stays empty —
// nothing renders.
QtObject {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: !!(root.device && root.device.isLaptopBattery && root.device.isPresent)

    property var samples: [] // [{ t: epochMs, percent: 0..100 }]
    property bool historyReady: false
    readonly property int maxSamples: 288 // 24h at 5-minute sampling

    // Pure — exported for direct testing (tests/qml/tst_battery_history.qml).
    function pushSample(history, sample, maxLength) {
        const next = history.concat([sample]);
        return next.length > maxLength ? next.slice(next.length - maxLength) : next;
    }

    function sample() {
        if (!root.available) return;
        root.samples = root.pushSample(root.samples, {
            t: Date.now(),
            percent: Math.round(root.device.percentage * 100)
        }, root.maxSamples);
        root._save();
    }

    property Timer sampleTimer: Timer {
        interval: 5 * 60 * 1000
        running: root.available && root.historyReady
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    function _save() {
        historyFile.setText(JSON.stringify(root.samples));
    }

    property FileView historyFile: FileView {
        path: Quickshell.statePath("battery-history.json")
        printErrors: false
        atomicWrites: true
        preload: true
        onLoaded: {
            try {
                const parsed = JSON.parse(historyFile.text());
                if (Array.isArray(parsed)) root.samples = parsed;
            } catch (e) {
                // First run / empty file.
            }
            root.historyReady = true;
        }
        onLoadFailed: root.historyReady = true
    }
}
