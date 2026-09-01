import QtQuick
import Quickshell
import Quickshell.Io
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
        console.warn("BLUETOOTH_AUDIO_TEST_PASS");
        root._terminateDelay.start();
    }
    function reportFailure(error) {
        console.error("BLUETOOTH_AUDIO_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    BluetoothDeviceCore { id: devices; devices: []; audioNodes: [] }

    function test_normalizeAddressStripsColonsAndCase() {
        devices.devices = [{ path: "/device/one", address: "AA:BB:CC:11:22:33", name: "Headphones" }];
        devices.audioNodes = [{ properties: {
            "device.api": "bluez5", "api.bluez5.address": "aa:bb:cc:11:22:33",
            "api.bluez5.codec": "sbc_xq", "api.bluez5.profile": "a2dp-sink"
        }}];
        root.compare(devices.state.devices[0].id, "AA:BB:CC:11:22:33");
        root.compare(devices.state.devices[0].audio.codec, "SBC-XQ");
        root.compare(devices.state.devices[0].audio.profile, "A2DP");
    }

    function test_friendlyProfileMapsKnownValues() {
        devices.devices = [{ path: "/device/one", address: "11:22", name: "Keyboard" }];
        devices.audioNodes = [];
        root.compare(devices.state.devices[0].audio, null);
    }

    function test_extractProfileReturnsNullWithoutCodecOrProfile() {
        devices.devices = [{ path: "/device/one", address: "11:22" }];
        devices.audioNodes = [{ properties: { "device.api": "bluez5", "api.bluez5.address": "11:22" } }];
        root.compare(devices.state.devices[0].audio, null);
    }

    function test_extractProfileCombinesCodecAndProfile() {
        devices.audioNodes = [{ properties: { "api.bluez5.address": "11:22", "api.bluez5.codec": "aac", "api.bluez5.profile": "a2dp-sink" } }];
        const result = devices.state.devices[0].audio;
        root.compare(result.codec, "AAC");
        root.compare(result.profile, "A2DP");
    }

    function test_extractProfileHandlesCodecOnly() {
        devices.audioNodes = [{ properties: { "api.bluez5.address": "11:22", "api.bluez5.codec": "sbc" } }];
        const result = devices.state.devices[0].audio;
        root.compare(result.codec, "SBC");
        root.compare(result.profile, "");
    }

    function test_extractProfilePolishesCompoundCodecLabels() {
        devices.audioNodes = [{ properties: { "api.bluez5.address": "11:22", "api.bluez5.codec": "sbc_xq" } }];
        const result = devices.state.devices[0].audio;
        root.compare(result.codec, "SBC-XQ");
    }

    // Regression test for the final-review C1 finding: bluez5 sink nodes on
    // this machine have no device.bus key at all (only device.api=bluez5 and
    // api.bluez5.address), so the classifier must not require device.bus.
    function test_isBluetoothSinkPropsRecognizesRealBluez5Node() {
        devices.devices = [{ path: "/device/two", address: "34:09:C9:A5:6B:2A" }];
        devices.audioNodes = [{ properties: { "device.api": "bluez5", "api.bluez5.address": "34:09:C9:A5:6B:2A", "api.bluez5.codec": "sbc_xq" } }];
        root.compare(devices.state.devices[0].audio.codec, "SBC-XQ");
    }

    function test_isBluetoothSinkPropsRecognizesDeviceBusFallback() {
        devices.devices = [{ path: "/device/three", address: "44:55" }];
        devices.audioNodes = [{ properties: { "device.bus": "bluetooth", "api.bluez5.address": "44:55", "api.bluez5.codec": "sbc" } }];
        root.compare(devices.state.devices[0].audio.codec, "SBC");
    }

    function test_isBluetoothSinkPropsRejectsNonBluetoothNodes() {
        devices.devices = [{ path: "/device/four", address: "66:77" }];
        devices.audioNodes = [{ properties: { "device.bus": "pci", "api.bluez5.codec": "sbc" } }];
        root.compare(devices.state.devices[0].audio, null);
    }

    Component.onCompleted: {
        try {
            root.test_normalizeAddressStripsColonsAndCase();
            root.test_friendlyProfileMapsKnownValues();
            root.test_extractProfileReturnsNullWithoutCodecOrProfile();
            root.test_extractProfileCombinesCodecAndProfile();
            root.test_extractProfileHandlesCodecOnly();
            root.test_extractProfilePolishesCompoundCodecLabels();
            root.test_isBluetoothSinkPropsRecognizesRealBluez5Node();
            root.test_isBluetoothSinkPropsRecognizesDeviceBusFallback();
            root.test_isBluetoothSinkPropsRejectsNonBluetoothNodes();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
