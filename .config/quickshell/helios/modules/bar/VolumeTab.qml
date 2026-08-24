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

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        Row {
            id: volumeRow
            width: parent.width
            spacing: 12

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.muted ? "volume_off"
                    : root.volume > 0.5 ? "volume_up"
                    : root.volume > 0 ? "volume_down" : "volume_mute"
                onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - 44 - 24
                value: root.muted ? 0 : root.volume
                // Output only — pushing past 100% is real gain, not just a
                // louder-sounding UI, so it stays capped at 1.0 for input.
                maxValue: 1.5
                markerAt: 1.0
                fillColor: (!root.muted && root.volume > 1) ? Colors.danger : Colors.accent
                onMoved: v => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v; } }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: Math.round((root.muted ? 0 : root.volume) * 100) + "%"
            }
        }

        StyledText {
            text: "Output"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        ListView {
            id: outputList
            width: parent.width - 8
            height: Math.min(176, Math.max(44, root.sinks.length * 44))
            clip: true
            spacing: 2
            model: root.sinks
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: outputList }

            delegate: HoverRow {
                id: row
                required property var modelData
                required property int index

                readonly property bool isDefault: root.sink && root.sink.id === modelData.id

                width: outputList.width
                height: 40
                highlighted: isDefault
                onClicked: Pipewire.preferredDefaultAudioSink = row.modelData

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "speaker"
                        font.pixelSize: 16
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: row.width - 16 - 16 - 22
                        elide: Text.ElideRight
                        text: row.modelData.description || row.modelData.nickname || row.modelData.name
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.isDefault
                        icon: "check"
                        font.pixelSize: 16
                    }
                }
            }
        }

        StyledText {
            text: "Input"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        Row {
            id: micRow
            width: parent.width
            spacing: 12

            readonly property real micVolume: root.source && root.source.audio ? root.source.audio.volume : 0
            readonly property bool micMuted: root.source && root.source.audio ? root.source.audio.muted : true

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: micRow.micMuted ? "mic_off" : "mic"
                onClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - 44 - 24
                value: micRow.micMuted ? 0 : micRow.micVolume
                onMoved: v => { if (root.source && root.source.audio) { root.source.audio.muted = false; root.source.audio.volume = v; } }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: Math.round((micRow.micMuted ? 0 : micRow.micVolume) * 100) + "%"
            }
        }

        ListView {
            id: inputList
            width: parent.width - 8
            height: Math.min(176, Math.max(44, root.sources.length * 44))
            clip: true
            spacing: 2
            model: root.sources
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: inputList }

            delegate: HoverRow {
                id: inRow
                required property var modelData
                required property int index

                readonly property bool isDefault: root.source && root.source.id === modelData.id

                width: inputList.width
                height: 40
                highlighted: isDefault
                onClicked: Pipewire.preferredDefaultAudioSource = inRow.modelData

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "mic"
                        font.pixelSize: 16
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: inRow.width - 16 - 16 - 22
                        elide: Text.ElideRight
                        text: inRow.modelData.description || inRow.modelData.nickname || inRow.modelData.name
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: inRow.isDefault
                        icon: "check"
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}
