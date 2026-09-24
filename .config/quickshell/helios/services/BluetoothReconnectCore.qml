import QtQuick
import Quickshell.Bluetooth as QsBluetooth

// Picks the target for Bluetooth.qml's trusted-device reconnect loop. Takes
// plain device objects so tests don't need BlueZ. Same split as
// BluetoothDeviceCore.
QtObject {
    id: root

    function _id(device) { return device.address || device.dbusPath; }

    function missingTrustedDevice(devices, excludeId) {
        return devices.find(device => device.trusted && !device.connected && root._id(device) !== excludeId) || null;
    }

    function idleMissingTrustedDevice(devices, excludeId) {
        return devices.find(device => device.trusted && !device.connected && root._id(device) !== excludeId
            && !device.pairing && device.state !== QsBluetooth.BluetoothDeviceState.Connecting) || null;
    }

    function anyDeviceNegotiating(devices) {
        return devices.some(device => device.pairing || device.state === QsBluetooth.BluetoothDeviceState.Connecting);
    }
}
