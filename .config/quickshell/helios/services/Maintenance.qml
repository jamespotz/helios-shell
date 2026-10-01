pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Fedora system-maintenance status: pending dnf/flatpak updates, reboot
// required, pending firmware updates, and failed systemd units — the things
// Fedora Workstation doesn't surface anywhere in a Hyprland session. Same
// one-shot Process + StdioCollector pattern as services/Calendar.qml, on two
// timers: a long one for the network-touching checks (maintenance-info.py)
// and a short one for the free local systemctl --failed check.
QtObject {
    id: root

    property bool checking: false
    property double lastCheckedAt: 0

    property var dnfUpdates: null
    property var dnfPackages: []
    property var flatpakUpdates: null
    property var rebootRequired: null
    property var firmwareUpdates: []
    property var failedUnits: []

    readonly property int updateCount: (root.dnfUpdates || 0) + (root.flatpakUpdates || 0)
    readonly property bool hasAlert: root.updateCount > 0 || !!root.rebootRequired
        || root.firmwareUpdates.length > 0 || root.failedUnits.length > 0

    function refresh() {
        root.checking = true;
        infoProc.running = false;
        infoProc.running = true;
        unitsProc.running = false;
        unitsProc.running = true;
    }

    // Opens a terminal that applies the pending updates, since sudo needs a
    // real prompt. The dnf packages are named explicitly: a bare `dnf upgrade`
    // as root reads root's own metadata cache, which can lag behind the user
    // cache this check reads (a stale mirror) and then silently finds nothing.
    // The terminal asks the shell to re-check once it's done.
    function update() {
        const steps = [];
        if (root.dnfPackages.length > 0)
            steps.push("sudo dnf upgrade --refresh " + root.dnfPackages.map(p => "'" + p + "'").join(" "));
        if (root.flatpakUpdates > 0)
            steps.push("flatpak update");
        if (steps.length === 0) return;
        steps.push("quickshell -c helios ipc call maintenance refresh >/dev/null");
        steps.push("printf '\\nPress Enter to close'; read -r _");
        AppLaunch.exec([Config.terminal, "-e", "sh", "-c", steps.join("; ")]);
    }

    property Process infoProc: Process {
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/island/maintenance-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                root.lastCheckedAt = Date.now();
                try {
                    const parsed = JSON.parse(text);
                    root.dnfUpdates = parsed.dnf_updates;
                    root.dnfPackages = parsed.dnf_packages || [];
                    root.flatpakUpdates = parsed.flatpak_updates;
                    root.rebootRequired = parsed.reboot_required;
                    root.firmwareUpdates = parsed.firmware_updates || [];
                } catch (e) {
                    console.warn("[Maintenance] failed to parse maintenance-info.py output:", e);
                }
            }
        }
    }

    property Process unitsProc: Process {
        command: ["systemctl", "--failed", "--no-legend", "--plain"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.failedUnits = text.split("\n")
                    .map(line => line.trim())
                    .filter(line => line.length > 0)
                    .map(line => line.split(/\s+/)[0]);
            }
        }
    }

    Component.onCompleted: root.refresh()

    // dnf/flatpak/fwupd hit the network — every 2 hours is plenty.
    property Timer slowTimer: Timer {
        interval: 2 * 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // systemctl --failed is a free local query — worth checking often.
    property Timer failedUnitsTimer: Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            unitsProc.running = false;
            unitsProc.running = true;
        }
    }
}
