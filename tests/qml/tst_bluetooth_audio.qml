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

    function test_normalizeAddressStripsColonsAndCase() {
        root.compare(BluetoothAudio.normalizeAddress("AA:BB:CC:11:22:33"), "aabbcc112233");
        root.compare(BluetoothAudio.normalizeAddress(""), "");
        root.compare(BluetoothAudio.normalizeAddress(undefined), "");
    }

    function test_friendlyProfileMapsKnownValues() {
        root.compare(BluetoothAudio.friendlyProfile("a2dp-sink"), "A2DP");
        root.compare(BluetoothAudio.friendlyProfile("headset-head-unit"), "HFP/HSP");
        root.compare(BluetoothAudio.friendlyProfile("some-custom-profile"), "some-custom-profile");
        root.compare(BluetoothAudio.friendlyProfile(""), "");
    }

    function test_extractProfileReturnsNullWithoutCodecOrProfile() {
        root.compare(BluetoothAudio.extractProfile({}), null);
        root.compare(BluetoothAudio.extractProfile(null), null);
    }

    function test_extractProfileCombinesCodecAndProfile() {
        const result = BluetoothAudio.extractProfile({
            "api.bluez5.codec": "aac",
            "api.bluez5.profile": "a2dp-sink"
        });
        root.compare(result.codec, "AAC");
        root.compare(result.profile, "A2DP");
    }

    function test_extractProfileHandlesCodecOnly() {
        const result = BluetoothAudio.extractProfile({ "api.bluez5.codec": "sbc" });
        root.compare(result.codec, "SBC");
        root.compare(result.profile, "");
    }

    function test_extractProfilePolishesCompoundCodecLabels() {
        const result = BluetoothAudio.extractProfile({ "api.bluez5.codec": "sbc_xq" });
        root.compare(result.codec, "SBC-XQ");
    }

    // Regression test for the final-review C1 finding: bluez5 sink nodes on
    // this machine have no device.bus key at all (only device.api=bluez5 and
    // api.bluez5.address), so the classifier must not require device.bus.
    function test_isBluetoothSinkPropsRecognizesRealBluez5Node() {
        root.verify(BluetoothAudio.isBluetoothSinkProps({
            "device.api": "bluez5",
            "api.bluez5.address": "34:09:C9:A5:6B:2A",
            "api.bluez5.codec": "sbc_xq",
            "api.bluez5.profile": "a2dp-sink"
        }), "expected a real bluez5 node with no device.bus to be recognized");
    }

    function test_isBluetoothSinkPropsRecognizesDeviceBusFallback() {
        root.verify(BluetoothAudio.isBluetoothSinkProps({ "device.bus": "bluetooth" }),
            "expected device.bus === bluetooth to still be accepted as a fallback signal");
    }

    function test_isBluetoothSinkPropsRejectsNonBluetoothNodes() {
        root.verify(!BluetoothAudio.isBluetoothSinkProps({}),
            "expected empty properties to be rejected");
        root.verify(!BluetoothAudio.isBluetoothSinkProps({ "device.bus": "pci" }),
            "expected a non-bluetooth device.bus to be rejected");
        root.verify(!BluetoothAudio.isBluetoothSinkProps(null),
            "expected null properties to be rejected");
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
