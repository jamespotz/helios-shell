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

    // User disconnects the R60i from the panel. The reconnect loop must
    // leave it alone. See Bluetooth.qml's _userDisconnectedIds.
    function test_reconnectTargetExcludesUserDisconnectedIds() {
        const devices = [{ address: "R60I", paired: true, trusted: true, connected: false }];
        root.compare(core.reconnectTarget(devices, { R60I: true }, ""), null, "excluded device should not be targeted");
        root.compare(core.reconnectTarget(devices, {}, "").address, "R60I", "non-excluded device is still targeted");
    }

    // Two devices disconnected by hand. Both stay excluded, not just the
    // most recent one.
    function test_reconnectTargetExcludesEveryUserDisconnect() {
        const devices = [
            { address: "A", paired: true, trusted: true, connected: false },
            { address: "B", paired: true, trusted: true, connected: false }
        ];
        root.compare(core.reconnectTarget(devices, { A: true, B: true }, ""), null);
    }

    // Two trusted devices missing, one disconnected by hand and one out of
    // range. Excluding the first must still return the second.
    function test_reconnectTargetPicksNextWhenFirstExcluded() {
        const devices = [
            { address: "A", paired: true, trusted: true, connected: false },
            { address: "B", paired: true, trusted: true, connected: false }
        ];
        root.compare(core.reconnectTarget(devices, { A: true }, "").address, "B", "should fall through to the other missing device");
    }

    // One device reconnecting must not hide a second trusted device that's
    // still missing.
    function test_reconnectTargetIgnoresNowConnectedDevice() {
        const devices = [
            { address: "A", paired: true, trusted: true, connected: true },
            { address: "B", paired: true, trusted: true, connected: false }
        ];
        root.compare(core.reconnectTarget(devices, {}, "").address, "B");
    }

    // Bonded devices reconnect on their own. The loop must not scan for
    // them, which would disturb audio on a device that's already playing.
    function test_reconnectTargetSkipsBondedDevices() {
        const devices = [{ address: "A", trusted: true, bonded: true, connected: false }];
        root.compare(core.reconnectTarget(devices, {}, ""), null);
    }

    // A device the user just asked to connect is retried even when bonded
    // or untrusted, so a flaky first connect isn't lost.
    function test_reconnectTargetIncludesRequestedDevice() {
        const devices = [{ address: "A", paired: true, trusted: false, bonded: true, connected: false }];
        root.compare(core.reconnectTarget(devices, {}, "A").address, "A");
    }

    function test_idleReconnectTargetSkipsPairingOrConnectingDevices() {
        const pairing = [{ address: "A", paired: true, trusted: true, connected: false, pairing: true, state: 0 }];
        root.compare(core.idleReconnectTarget(pairing, {}, "", ""), null, "a mid-pair device is not an idle target");

        const mixed = [
            { address: "A", paired: true, trusted: true, connected: false, pairing: true, state: 0 },
            { address: "B", paired: true, trusted: true, connected: false, pairing: false, state: 0 }
        ];
        root.compare(core.idleReconnectTarget(mixed, {}, "", "").address, "B", "should skip the busy one and find the idle one");
    }

    // A device that's off for good must not take every attempt: targets
    // take turns after the last one tried.
    function test_idleReconnectTargetRotatesAfterLastAttempt() {
        const devices = [
            { address: "A", paired: true, trusted: true, connected: false, pairing: false, state: 0 },
            { address: "B", paired: true, trusted: true, connected: false, pairing: false, state: 0 }
        ];
        root.compare(core.idleReconnectTarget(devices, {}, "", "").address, "A", "starts at the first target");
        root.compare(core.idleReconnectTarget(devices, {}, "", "A").address, "B", "moves on after A");
        root.compare(core.idleReconnectTarget(devices, {}, "", "B").address, "A", "wraps around");
    }

    function test_idleReconnectTargetPrefersRequestedDevice() {
        const devices = [
            { address: "A", paired: true, trusted: true, connected: false, pairing: false, state: 0 },
            { address: "B", paired: true, trusted: true, connected: false, pairing: false, state: 0 }
        ];
        root.compare(core.idleReconnectTarget(devices, {}, "B", "B").address, "B");
    }

    // Re-pairing in the background is only safe for audio devices, which
    // pair without a prompt.
    function test_reconnectTargetOnlyRepairsAudioDevices() {
        const keyboard = [{ address: "K", icon: "input-keyboard", paired: false, trusted: true, connected: false }];
        root.compare(core.reconnectTarget(keyboard, {}, ""), null, "unpaired keyboard would prompt for a PIN");
        const headset = [{ address: "H", icon: "audio-headset", paired: false, trusted: true, connected: false }];
        root.compare(core.reconnectTarget(headset, {}, "").address, "H", "unpaired headset re-pairs silently");
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
            root.test_reconnectTargetExcludesUserDisconnectedIds();
            root.test_reconnectTargetExcludesEveryUserDisconnect();
            root.test_reconnectTargetPicksNextWhenFirstExcluded();
            root.test_reconnectTargetIgnoresNowConnectedDevice();
            root.test_reconnectTargetSkipsBondedDevices();
            root.test_reconnectTargetIncludesRequestedDevice();
            root.test_idleReconnectTargetSkipsPairingOrConnectingDevices();
            root.test_idleReconnectTargetRotatesAfterLastAttempt();
            root.test_idleReconnectTargetPrefersRequestedDevice();
            root.test_reconnectTargetOnlyRepairsAudioDevices();
            root.test_anyDeviceNegotiatingDetectsPairing();
            root.test_anyDeviceNegotiatingDetectsConnectingState();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
