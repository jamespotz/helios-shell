import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI

ShellRoot {
    id: root
    property int phase: 0
    property var scanLink: null
    property var cached: null
    TestCase { id: input; name: "WifiScan"; when: false }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    function verify(ok, message) { if (!ok) throw new Error(message); }
    function find(item) {
        if (item.text === "Scan" && item.icon === undefined) return item.parent.parent;
        for (const child of item.children || []) { const result = find(child); if (result) return result; }
        return null;
    }
    FloatingWindow {
        visible: true
        implicitWidth: 380
        implicitHeight: 600
        IslandUI.WifiDestination { id: wifi; width: 320 }
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            try {
                if (phase === 0) {
                    if (!WifiNetworks.loaded) return;
                    root.cached = JSON.stringify(WifiNetworks.networks);
                    root.scanLink = find(wifi);
                    verify(scanLink, "scan action exists");
                    scanLink.visible = true;
                    scanLink.clicked();
                    verify(WifiNetworks.scanning, "first click starts scan");
                    verify(scanLink.enabled, "scan must remain clickable to stop");
                    scanLink.clicked();
                    verify(!WifiNetworks.scanning, "second click stops scan immediately");
                    verify(JSON.stringify(WifiNetworks.networks) === root.cached, "cancel preserves cached networks");
                    phase++;
                    return;
                }
                if (phase === 1) {
                    verify(!WifiNetworks.scanning && !WifiNetworks.scanTimer.running, "late process exit cannot restart cancelled scan");
                    WifiNetworks.scan();
                    WifiNetworks.scanTimer.interval = 150;
                    phase++;
                    return;
                }
                if (phase === 2) {
                    if (!WifiNetworks.scanTimer.running) return;
                    scanLink.forceActiveFocus(); input.keyClick(Qt.Key_Space);
                    verify(!WifiNetworks.scanning && !WifiNetworks.scanTimer.running, "keyboard stop cancels settle timer");
                    WifiNetworks.scan();
                    phase++;
                    return;
                }
                if (WifiNetworks.scanning) return;
                verify(!WifiNetworks.scanTimer.running, "normal completion releases scan state");
                verify(WifiNetworks.loaded && WifiNetworks.networks.length === 1, "normal completion refreshes networks");
                console.warn("WIFI_SCAN_TEST_PASS");
            } catch (error) {
                console.error("WIFI_SCAN_TEST_FAIL", error.toString());
            }
            terminator.running = true;
        }
    }
}
