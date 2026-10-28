import QtQuick

QtObject {
    property string preferredName: ""
    property var knownNames: []
    property bool synced: false
    property var startupNames: []
    function update(names, ready) {
        if (!ready || !synced) {
            seed(names);
            startupNames = names.slice();
            synced = ready;
            return "";
        }
        startupNames = startupNames.filter(name => names.includes(name));
        return arrived(names);
    }
    function canRouteConnection(name, ready) {
        return !preferredName || (ready && name === preferredName && !startupNames.includes(name));
    }
    function seed(names) { knownNames = names.slice(); }
    function arrived(names) {
        const added = names.filter(name => !knownNames.includes(name));
        knownNames = names.slice();
        return preferredName && added.includes(preferredName) ? preferredName : "";
    }
    // One Bluetooth check for every audio node: BlueZ nodes carry the device
    // address, though some only say so through device.api, device.bus or
    // their name.
    function isBluetoothSink(name, properties) {
        const p = properties || {};
        return !!p["api.bluez5.address"] || String(p["device.api"] || "").toLowerCase() === "bluez5"
            || String(p["device.bus"] || "").toLowerCase() === "bluetooth" || String(name || "").startsWith("bluez_output.");
    }

    // Bluetooth reconnects: a device that connects waits in `pending` until
    // its audio node shows up (a moment after the connect), is routed once,
    // and isn't routed again until it disconnects and reconnects. Keyed on
    // the BlueZ connection, not the node: switching Headset mode (or an app
    // like Zoom opening the mic) tears the sink down and recreates it, and
    // routing on that looked like a fresh connect. Returns the next state
    // and the node name to route to ("" for none).
    function bluetoothStep(state, connectedIds, audioDevices) {
        const added = connectedIds.filter(id => !state.connected.includes(id));
        let pending = state.pending.filter(id => connectedIds.includes(id)).concat(added);
        const ready = audioDevices.find(device => pending.includes(device.id));
        if (ready) pending = pending.filter(id => id !== ready.id);
        return { state: { connected: connectedIds, pending: pending }, route: ready ? ready.nodeName : "" };
    }

    function prefer(name, names) {
        preferredName = name;
        seed(names);
        return name && names.includes(name) ? name : "";
    }
}
