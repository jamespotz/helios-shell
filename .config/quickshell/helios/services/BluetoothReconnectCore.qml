import QtQuick
import Quickshell.Bluetooth as QsBluetooth

// Picks the target for Bluetooth.qml's reconnect loop. Takes plain device
// objects so tests don't need BlueZ. Same split as BluetoothDeviceCore.
//
// Bonded devices reconnect on their own, so the loop only targets trusted
// devices without a bond, plus the device the user last asked to connect
// (covers a flaky first connect). Devices in `excludedIds` were
// disconnected by hand and are left alone. A device that lost its pairing
// is only a target when it's audio: those re-pair without a prompt, while
// a phone or keyboard would pop a PIN dialog out of nowhere.
QtObject {
    id: root

    function _id(device) { return device.address || device.dbusPath; }

    function isTarget(device, excludedIds, requestedId) {
        const id = root._id(device);
        return !device.connected && !excludedIds[id]
            && (device.paired || (device.icon || "").startsWith("audio-"))
            && (id === requestedId || (device.trusted && !device.bonded));
    }

    function reconnectTarget(devices, excludedIds, requestedId) {
        return devices.find(device => root.isTarget(device, excludedIds, requestedId)) || null;
    }

    // The requested device goes first. Otherwise targets take turns after
    // `lastId`, so one device that's off for good can't use up every
    // attempt while another sits in range.
    function idleReconnectTarget(devices, excludedIds, requestedId, lastId) {
        const idle = devices.filter(device => root.isTarget(device, excludedIds, requestedId)
            && !device.pairing && device.state !== QsBluetooth.BluetoothDeviceState.Connecting);
        if (idle.length === 0) return null;
        const requested = idle.find(device => root._id(device) === requestedId);
        if (requested) return requested;
        const last = idle.findIndex(device => root._id(device) === lastId);
        return idle[(last + 1) % idle.length];
    }

    function anyDeviceNegotiating(devices) {
        return devices.some(device => device.pairing || device.state === QsBluetooth.BluetoothDeviceState.Connecting);
    }
}
