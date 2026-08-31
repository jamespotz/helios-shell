pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Bluetooth codec/audio-profile lookup for the connected device, read off
// WirePlumber's PipeWire node properties. BlueZ itself (services/Bluetooth.qml)
// has no codec/profile concept — that's negotiated by the PipeWire bluez5
// session-manager module, which stamps it onto the node it creates for the
// device's audio sink.
//
// device.api/api.bluez5.address/api.bluez5.codec/api.bluez5.profile (the
// property key names below) were verified against a real connected device
// (Soundcore R60i NC) during final review, by dumping live node properties
// with `pw-dump | grep -A30 bluez5`. Bluez5 sink nodes do NOT reliably carry
// a device.bus key — this build's nodes had none at all — so the filter
// below no longer depends on it; it's kept only as one of three fallback
// signals in case some other WirePlumber build does stamp it. If a future
// WirePlumber version renames these properties, the Audio Profile card will
// just read "—" — update the three key constants after inspecting real
// properties (`pw-dump | grep -A30 bluez5`, or temporarily
// `console.log(JSON.stringify(node.properties))` in `bluetoothSinks` below)
// rather than guessing.
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

    // Polish for the raw api.bluez5.codec value — a plain .toUpperCase()
    // gets most codecs right (SBC, AAC, LDAC) but mangles the compound ones
    // (sbc_xq -> "SBC_XQ", aptx_hd -> "APTX_HD"); this maps the known
    // bluez5 codec ids to their conventional display spelling.
    readonly property var _codecLabels: ({
        "sbc": "SBC",
        "sbc_xq": "SBC-XQ",
        "aac": "AAC",
        "aptx": "aptX",
        "aptx_hd": "aptX HD",
        "aptx_ll": "aptX LL",
        "aptx_ll_duplex": "aptX LL",
        "ldac": "LDAC"
    })

    function normalizeAddress(address) {
        return String(address || "").toLowerCase().replace(/:/g, "");
    }

    function friendlyProfile(profileKey) {
        if (!profileKey) return "";
        return root._profileLabels[String(profileKey).toLowerCase()] || String(profileKey);
    }

    function friendlyCodec(codecKey) {
        if (!codecKey) return "";
        return root._codecLabels[String(codecKey).toLowerCase()] || String(codecKey).toUpperCase();
    }

    function extractProfile(properties) {
        const props = properties || {};
        const codec = props[root.codecPropertyKey];
        const profile = props[root.profilePropertyKey];
        if (!codec && !profile) return null;
        return {
            codec: codec ? root.friendlyCodec(codec) : "",
            profile: root.friendlyProfile(profile)
        };
    }

    // Pure classification predicate (kept separate from bluetoothSinks so it
    // can be unit-tested without a live Pipewire.nodes binding). A node
    // counts as a Bluetooth sink if it carries the bluez5 address property,
    // or reports device.api "bluez5", or — as a last-resort fallback for
    // WirePlumber builds that do stamp it — device.bus "bluetooth". None of
    // these three is guaranteed present on every build, so we accept any one.
    function isBluetoothSinkProps(properties) {
        const p = properties || {};
        return !!p[root.addressPropertyKey]
            || String(p["device.api"] || "").toLowerCase() === "bluez5"
            || String(p["device.bus"] || "").toLowerCase() === "bluetooth";
    }

    // All real audio sinks — mirrors modules/bar/VolumeTab.qml's sink filter
    // (isSink && !isStream && real AudioSink type flag). We track every sink,
    // not just Bluetooth ones: a PwNode's `properties` stay empty until a
    // PwObjectTracker binds it, so we can't know which nodes are Bluetooth
    // sinks without first binding all of them (see bluetoothSinks below).
    readonly property var audioSinks: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream
            && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
        : []

    readonly property PwObjectTracker _tracker: PwObjectTracker { objects: root.audioSinks }

    // Now that every sink is bound and its properties are populated, narrow
    // down to the Bluetooth ones.
    readonly property var bluetoothSinks: root.audioSinks.filter(n =>
        root.isBluetoothSinkProps(n.properties))

    function profileForAddress(address) {
        const norm = root.normalizeAddress(address);
        if (!norm) return null;
        const node = root.bluetoothSinks.find(n =>
            root.normalizeAddress((n.properties || {})[root.addressPropertyKey]) === norm);
        if (!node) return null;
        return root.extractProfile(node.properties);
    }
}
