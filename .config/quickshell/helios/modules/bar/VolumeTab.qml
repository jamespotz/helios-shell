import QtQuick
import Quickshell.Services.Pipewire
import "../../services"
import "../../components"

Item {
    id: root

    // PipeWire's node graph also contains non-audio plumbing nodes (the
    // Dummy-Driver/Freewheel-Driver clock drivers, the Midi-Bridge/
    // bluez_midi.server MIDI bridges) that are neither a sink nor a stream,
    // so `!isSink && !isStream` alone let them leak into the input list.
    // Requiring the actual Audio(Sink|Source) type flag excludes them.
    readonly property var sinks: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink) : []
    readonly property var sources: Pipewire.nodes ? Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource) : []

    PwObjectTracker { objects: root.sinks.concat(root.sources) }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : true

    readonly property var source: Pipewire.defaultAudioSource
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : true

    // One focused control at a time (Control Center style) instead of both
    // Output and Input always fully expanded — cuts the tab's resting height
    // roughly in half and reads as a widget rather than a settings dump.
    property string mode: "output" // "output" | "input"
    readonly property bool isOutput: root.mode === "output"

    readonly property var activeDevices: root.isOutput ? root.sinks : root.sources
    readonly property var activeDefault: root.isOutput ? root.sink : root.source

    // Real per-device icon from PipeWire's own form-factor/bus metadata —
    // the same hints macOS's Sound picker uses — instead of one generic
    // speaker/mic glyph for every device regardless of what it actually is.
    function iconForNode(node) {
        const props = (node && node.properties) || {};
        const bus = String(props["device.bus"] || "").toLowerCase();
        const formFactor = String(props["device.form-factor"] || "").toLowerCase();
        if (bus === "bluetooth") return "bluetooth_audio";
        // Not every session manager mirrors device.bus onto the audio-sink
        // node itself, so also cross-check against the connected Bluetooth
        // device list (same service BluetoothTab/MediaCard already use) by
        // name — catches real headsets that PipeWire's own props miss.
        const label = (node && (node.description || node.nickname || node.name)) || "";
        const btDevices = Bluetooth.state.devices;
        if (label && btDevices.some(d => d.connected && d.name && label.includes(d.name))) return "bluetooth_audio";
        if (formFactor === "headset" || formFactor === "headphone") return "headphones";
        if (formFactor === "hdmi" || formFactor === "tv") return "tv";
        if (formFactor === "webcam") return "videocam";
        if (formFactor === "handset" || formFactor === "hands-free") return "phone_in_talk";
        return root.isOutput ? "speaker" : "mic";
    }

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // --- Output/Input segmented switch ----------------------------------
        SegmentedControl {
            width: parent.width
            model: [
                { value: "output", label: "Output", icon: "volume_up" },
                { value: "input", label: "Input", icon: "mic" }
            ]
            currentValue: root.mode
            onActivated: value => root.mode = value
        }

        // --- Hero volume card ------------------------------------------------
        Rectangle {
            width: parent.width
            height: 64
            radius: Colors.radiusLarge
            color: Colors.surfaceHigh

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.isOutput
                        ? (root.muted ? "volume_off" : root.volume > 0.5 ? "volume_up" : root.volume > 0 ? "volume_down" : "volume_mute")
                        : (root.micMuted ? "mic_off" : "mic")
                    onClicked: {
                        if (root.isOutput) { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted; }
                        else { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
                    }
                }

                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28 - 44 - 24
                    trackHeight: 8
                    value: root.isOutput ? (root.muted ? 0 : root.volume) : (root.micMuted ? 0 : root.micVolume)
                    // Output only — pushing past 100% is real gain, not just a
                    // louder-sounding UI, so it stays capped at 1.0 for input.
                    maxValue: root.isOutput ? 1.5 : 1
                    markerAt: root.isOutput ? 1.0 : -1
                    fillColor: (root.isOutput && !root.muted && root.volume > 1) ? Colors.danger : Colors.accent
                    onMoved: v => {
                        if (root.isOutput) { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v; } }
                        else { if (root.source && root.source.audio) { root.source.audio.muted = false; root.source.audio.volume = v; } }
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((root.isOutput ? (root.muted ? 0 : root.volume) : (root.micMuted ? 0 : root.micVolume)) * 100) + "%"
                }
            }
        }

        // --- Device list ---------------------------------------------------
        StyledText {
            text: root.isOutput ? "Output Devices" : "Input Devices"
            font.bold: true
        }

        StyledText {
            visible: root.activeDevices.length === 0
            text: "No devices found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // Wrapped so ScrollIndicator (anchors to its target's edges) is a
        // sibling of the Flickable rather than a child inside it; Qt
        // doesn't support a child anchoring to the Flickable it's inside
        // (see components/ScrollIndicator.qml).
        Item {
            id: deviceListWrap
            width: parent.width
            visible: root.activeDevices.length > 0
            height: Math.min(220, Math.max(0, root.activeDevices.length * 44))

            ListView {
                id: deviceList
                anchors.fill: parent
                clip: true
                spacing: 2
                model: root.activeDevices
                boundsBehavior: Flickable.StopAtBounds

                delegate: HoverRow {
                    id: devRow
                    required property var modelData
                    required property int index

                    readonly property bool isDefault: root.activeDefault && root.activeDefault.id === modelData.id

                    width: deviceList.width
                    height: 40
                    highlighted: isDefault
                    onClicked: {
                        if (root.isOutput) Pipewire.preferredDefaultAudioSink = devRow.modelData;
                        else Pipewire.preferredDefaultAudioSource = devRow.modelData;
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Colors.radiusSmall
                            color: Colors.surfaceHigh
                            anchors.verticalCenter: parent.verticalCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: root.iconForNode(devRow.modelData)
                                font.pixelSize: 15
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: devRow.width - 28 - 16 - 22
                            elide: Text.ElideRight
                            text: devRow.modelData.description || devRow.modelData.nickname || devRow.modelData.name
                        }

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: devRow.isDefault
                            icon: "check"
                            color: Colors.accent
                            font.pixelSize: 16
                        }
                    }
                }
            }

            ScrollIndicator { target: deviceList }
        }
    }
}
