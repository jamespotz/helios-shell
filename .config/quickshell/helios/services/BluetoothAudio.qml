pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
import "."

// Bluetooth codec/audio-profile lookup for the connected device, read off
// WirePlumber's PipeWire node properties. BlueZ itself (services/Bluetooth.qml)
// has no codec/profile concept — that's negotiated by the PipeWire bluez5
// session-manager module, which stamps it onto the node it creates for the
// device's audio sink.
//
// The property key names below (verified against this WirePlumber build's
// actual node dump during planning) are the ones the bluez5 SPA plugin uses
// as of PipeWire 1.x. If a future WirePlumber version renames them, the
// Audio Profile card will just read "Unknown" — update these three
// constants after inspecting real properties (`pw-dump | grep -A30 bluez5`,
// or temporarily `console.log(JSON.stringify(node.properties))` in
// `bluetoothSinks` below) rather than guessing.
QtObject {
    id: root

    readonly property string addressPropertyKey: "api.bluez5.address"
    readonly property string codecPropertyKey: "api.bluez5.codec"
    readonly property string profilePropertyKey: "api.bluez5.profile"

    readonly property var _profileLabels: ({
        "a2dp-sink": "A2DP",
        "a2dp_sink": "A2DP",
        "a2dp-source": "A2DP",
        "headset-head-unit": "HFP/HSP",
        "headset_head_unit": "HFP/HSP",
        "headset-audio-gateway": "HFP/HSP"
    })

    function normalizeAddress(address) {
        return String(address || "").toLowerCase().replace(/:/g, "");
    }

    function friendlyProfile(profileKey) {
        if (!profileKey) return "";
        return root._profileLabels[String(profileKey).toLowerCase()] || String(profileKey);
    }

    function extractProfile(properties) {
        const props = properties || {};
        const codec = props[root.codecPropertyKey];
        const profile = props[root.profilePropertyKey];
        if (!codec && !profile) return null;
        return {
            codec: codec ? String(codec).toUpperCase() : "",
            profile: root.friendlyProfile(profile)
        };
    }

    // Bluetooth sinks only — mirrors modules/bar/VolumeTab.qml's sink filter
    // (isSink && !isStream && real AudioSink type flag), further narrowed to
    // device.bus === "bluetooth".
    readonly property var bluetoothSinks: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream
            && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink
            && String((n.properties || {})["device.bus"] || "").toLowerCase() === "bluetooth")
        : []

    property PwObjectTracker _tracker: PwObjectTracker { objects: root.bluetoothSinks }

    function profileForAddress(address) {
        const norm = root.normalizeAddress(address);
        if (!norm) return null;
        const node = root.bluetoothSinks.find(n =>
            root.normalizeAddress((n.properties || {})[root.addressPropertyKey]) === norm);
        if (!node) return null;
        return root.extractProfile(node.properties);
    }
}
