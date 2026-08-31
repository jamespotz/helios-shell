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

    Component.onCompleted: {
        try {
            root.test_normalizeAddressStripsColonsAndCase();
            root.test_friendlyProfileMapsKnownValues();
            root.test_extractProfileReturnsNullWithoutCodecOrProfile();
            root.test_extractProfileCombinesCodecAndProfile();
            root.test_extractProfileHandlesCodecOnly();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
