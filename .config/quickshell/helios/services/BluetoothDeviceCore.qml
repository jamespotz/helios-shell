import QtQuick

QtObject {
    id: root

    required property var devices
    required property var audioNodes
    readonly property string addressPropertyKey: "api.bluez5.address"
    readonly property string codecPropertyKey: "api.bluez5.codec"
    readonly property string profilePropertyKey: "api.bluez5.profile"
    readonly property var profileLabels: ({ "a2dp-sink": "A2DP", "a2dp_sink": "A2DP", "a2dp-source": "A2DP", "headset-head-unit": "HFP/HSP", "headset_head_unit": "HFP/HSP", "headset-audio-gateway": "HFP/HSP" })
    readonly property var codecLabels: ({ "sbc": "SBC", "sbc_xq": "SBC-XQ", "aac": "AAC", "aptx": "aptX", "aptx_hd": "aptX HD", "aptx_ll": "aptX LL", "aptx_ll_duplex": "aptX LL", "ldac": "LDAC" })
    readonly property var state: ({
        devices: root.devices.map(device => ({
            id: device.address || device.path,
            name: device.name,
            alias: device.alias,
            address: device.address,
            icon: device.icon,
            paired: device.paired,
            connected: device.connected,
            trusted: device.trusted,
            nearby: device.rssi !== 0,
            batteryAvailable: device.batteryAvailable,
            battery: device.battery,
            pairing: device.pairing,
            audio: root._profileForAddress(device.address)
        }))
    })

    function _normalizeAddress(address) { return String(address || "").toLowerCase().replace(/:/g, ""); }
    function _friendlyProfile(key) { return key ? (root.profileLabels[String(key).toLowerCase()] || String(key)) : ""; }
    function _friendlyCodec(key) { return key ? (root.codecLabels[String(key).toLowerCase()] || String(key).toUpperCase()) : ""; }
    function _isBluetoothSink(properties) {
        const p = properties || {};
        return !!p[root.addressPropertyKey] || String(p["device.api"] || "").toLowerCase() === "bluez5" || String(p["device.bus"] || "").toLowerCase() === "bluetooth";
    }
    function _profileForAddress(address) {
        const normalized = root._normalizeAddress(address);
        const node = normalized ? root.audioNodes.find(candidate => {
            const props = candidate.properties || {};
            return root._isBluetoothSink(props) && root._normalizeAddress(props[root.addressPropertyKey]) === normalized;
        }) : null;
        if (!node) return null;
        const props = node.properties || {}, codec = props[root.codecPropertyKey], profile = props[root.profilePropertyKey];
        return codec || profile ? { codec: root._friendlyCodec(codec), profile: root._friendlyProfile(profile) } : null;
    }
}
