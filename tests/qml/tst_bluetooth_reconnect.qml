import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as QsBluetooth
import services

ShellRoot {
    id: root

    readonly property Process _terminator: Process {
        command: ["sh", "-c", 'kill -TERM "$PPID"']
    }
    readonly property Timer _terminateDelay: Timer {
        interval: 50
        onTriggered: root._terminator.running = true
    }

    function fail(message) {
        throw new Error(message);
    }
    function verify(value, message) {
        if (!value) root.fail(message || "verification failed");
    }
    function compare(actual, expected, message) {
        const a = JSON.stringify(actual);
        const e = JSON.stringify(expected);
        if (a !== e) root.fail((message || "values differ") + `: expected ${e}, got ${a}`);
    }
    function pass() {
        console.warn("BLUETOOTH_RECONNECT_TEST_PASS");
        root._terminateDelay.start();
    }
    function reportFailure(error) {
        console.error("BLUETOOTH_RECONNECT_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    BluetoothReconnectCore { id: core }

    // R60i placed back in its case, then the user disconnects it by hand
    // from the panel — the reconnect loop must not target it (see
    // Bluetooth.qml's disconnect()/_userDisconnectedId).
    function test_missingTrustedDeviceExcludesUserDisconnectedId() {
        const devices = [{ address: "R60I", trusted: true, connected: false }];
        root.compare(core.missingTrustedDevice(devices, "R60I"), null, "excluded device should not be targeted");
        root.compare(core.missingTrustedDevice(devices, "").address, "R60I", "non-excluded device is still targeted");
    }

    // Two trusted devices are both missing (e.g. one manually disconnected,
    // one out of range) — excluding the first must still surface the second
    // instead of the loop giving up entirely.
    function test_missingTrustedDevicePicksNextWhenFirstExcluded() {
        const devices = [
            { address: "A", trusted: true, connected: false },
            { address: "B", trusted: true, connected: false }
        ];
        root.compare(core.missingTrustedDevice(devices, "A").address, "B", "should fall through to the other missing device");
    }

    // Regression for the finding: one device reconnecting shouldn't strand
    // a second still-missing trusted device — the core must keep finding it.
    function test_missingTrustedDeviceIgnoresNowConnectedDevice() {
        const devices = [
            { address: "A", trusted: true, connected: true },
            { address: "B", trusted: true, connected: false }
        ];
        root.compare(core.missingTrustedDevice(devices, "").address, "B");
    }

    function test_idleMissingTrustedDeviceSkipsPairingOrConnectingDevices() {
        const pairing = [{ address: "A", trusted: true, connected: false, pairing: true, state: 0 }];
        root.compare(core.idleMissingTrustedDevice(pairing, ""), null, "a mid-pair device is not an idle target");

        const mixed = [
            { address: "A", trusted: true, connected: false, pairing: true, state: 0 },
            { address: "B", trusted: true, connected: false, pairing: false, state: 0 }
        ];
        root.compare(core.idleMissingTrustedDevice(mixed, "").address, "B", "should skip the busy one and find the idle one");
    }

    function test_anyDeviceNegotiatingDetectsPairing() {
        root.verify(core.anyDeviceNegotiating([{ pairing: true, state: 0 }]));
        root.verify(!core.anyDeviceNegotiating([{ pairing: false, state: 0 }]));
    }

    function test_anyDeviceNegotiatingDetectsConnectingState() {
        root.verify(core.anyDeviceNegotiating([{ pairing: false, state: QsBluetooth.BluetoothDeviceState.Connecting }]));
        root.verify(!core.anyDeviceNegotiating([{ pairing: false, state: QsBluetooth.BluetoothDeviceState.Connected }]));
    }

    Component.onCompleted: {
        try {
            root.test_missingTrustedDeviceExcludesUserDisconnectedId();
            root.test_missingTrustedDevicePicksNextWhenFirstExcluded();
            root.test_missingTrustedDeviceIgnoresNowConnectedDevice();
            root.test_idleMissingTrustedDeviceSkipsPairingOrConnectingDevices();
            root.test_anyDeviceNegotiatingDetectsPairing();
            root.test_anyDeviceNegotiatingDetectsConnectingState();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
