import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../services"
import "../../components"

// Per-app volume mixer with output routing — one row per app currently
// playing audio (a PipeWire AudioOutStream node), each with its own
// volume/mute (PwNodeAudioIface, same API VolumeIsland.qml uses for the
// system sink) and a picker to move that one app's output to a different
// sink. Quickshell's Pipewire service has no "move this stream" call, so
// routing shells out to `pactl move-sink-input` — same pattern Bluetooth.qml
// already uses `pactl -f json list cards` for what's outside that API.
Item {
    id: root

    readonly property var streams: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isStream && (n.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream)
        : []
    readonly property var sinks: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
        : []

    PwObjectTracker { objects: root.streams.concat(root.sinks) }

    // Which app's output-sink picker is expanded, if any.
    property string routingId: ""

    function appName(node) {
        return (node.properties && node.properties["application.name"]) || node.description || node.name;
    }

    // pactl's sink-input index and sink index both equal PipeWire's
    // object.serial (verified live: `pactl -f json list sink-inputs`'s
    // "index"/"sink" fields match the stream/sink's own "object.serial"
    // property) — object.id (node.id here) is a different number and does
    // NOT work with pactl, so routing must read object.serial specifically.
    function serial(node) {
        return node.properties ? node.properties["object.serial"] : null;
    }

    function currentSinkFor(stream) {
        const groups = Pipewire.linkGroups.values;
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            if (g.source && g.source.id === stream.id && g.target) return g.target;
        }
        return null;
    }

    function moveOutput(stream, sink) {
        const from = root.serial(stream);
        const to = root.serial(sink);
        if (!from || !to) return;
        moveProc.command = ["pactl", "move-sink-input", String(from), String(to)];
        moveProc.running = false;
        moveProc.running = true;
        root.routingId = "";
    }

    property Process moveProc: Process {}

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        StyledText { text: "Audio Mixer"; font.bold: true }

        StyledText {
            visible: root.streams.length === 0
            text: "No apps are playing audio"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        Item {
            id: listWrap
            width: parent.width
            visible: root.streams.length > 0
            height: Math.min(320, listCol.implicitHeight)

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: listCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listCol
                    width: flick.width
                    spacing: 8

                    Repeater {
                        model: root.streams

                        delegate: Column {
                            id: appRow
                            required property var modelData
                            width: listCol.width
                            spacing: 6

                            readonly property var currentSink: root.currentSinkFor(modelData)
                            readonly property bool routing: root.routingId === root.serial(modelData)

                            Rectangle {
                                width: parent.width
                                height: 60
                                radius: Colors.radiusSmall
                                color: Colors.surfaceHigh

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    IconButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: (appRow.modelData.audio && appRow.modelData.audio.muted) ? "volume_off" : "volume_up"
                                        onClicked: if (appRow.modelData.audio) appRow.modelData.audio.muted = !appRow.modelData.audio.muted
                                    }

                                    Column {
                                        width: parent.width - 30 - 10 - 30 - 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        StyledText {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: root.appName(appRow.modelData)
                                            font.weight: Font.Medium
                                        }

                                        Slider {
                                            width: parent.width
                                            trackHeight: 6
                                            value: appRow.modelData.audio ? (appRow.modelData.audio.muted ? 0 : appRow.modelData.audio.volume) : 0
                                            maxValue: 1.5
                                            markerAt: 1.0
                                            onMoved: v => {
                                                if (!appRow.modelData.audio) return;
                                                appRow.modelData.audio.muted = false;
                                                appRow.modelData.audio.volume = v;
                                            }
                                        }
                                    }

                                    IconButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: "speaker_group"
                                        active: appRow.routing
                                        onClicked: root.routingId = appRow.routing ? "" : root.serial(appRow.modelData)
                                    }
                                }
                            }

                            StyledText {
                                visible: !appRow.routing
                                text: "Output: " + (appRow.currentSink ? (appRow.currentSink.description || appRow.currentSink.name) : "Unknown")
                                font.pixelSize: Config.fontSize - 3
                                color: Colors.subtext
                                leftPadding: 6
                            }

                            // ─── Output picker ─────────────────────────────
                            Column {
                                width: parent.width
                                visible: appRow.routing
                                spacing: 2
                                leftPadding: 6
                                rightPadding: 6

                                Repeater {
                                    model: root.sinks

                                    delegate: HoverRow {
                                        id: sinkRow
                                        required property var modelData

                                        readonly property bool isCurrent: appRow.currentSink && appRow.currentSink.id === modelData.id

                                        width: parent ? parent.width - 12 : 0
                                        height: 32
                                        highlighted: isCurrent
                                        onClicked: root.moveOutput(appRow.modelData, sinkRow.modelData)

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            StyledText {
                                                width: parent.width - 18
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                                font.pixelSize: Config.fontSize - 2
                                                text: sinkRow.modelData.description || sinkRow.modelData.name
                                            }

                                            MaterialIcon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: sinkRow.isCurrent
                                                icon: "check"
                                                color: Colors.accent
                                                font.pixelSize: 14
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ScrollIndicator { target: flick }
        }
    }
}
