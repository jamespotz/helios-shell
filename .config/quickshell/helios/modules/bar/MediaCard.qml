import QtQuick
import Quickshell.Widgets
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var media: MediaSession.state
    readonly property var track: root.media.track

    readonly property var connectedDevice: Bluetooth.state.devices.find(d => d.connected) || null

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }

    // --- Equalizer, wired to a real EasyEffects output preset. EasyEffects
    // has no live per-band-gain API, only whole-preset load — see
    // easyeffects-eq.py for how band drags get turned into a loadable preset.
    // Band values/preset selection live in the Equalizer singleton, not here,
    // so they survive the island closing and reopening (PanelWrapper's
    // Loader destroys and recreates this component on every tab switch) and
    // only reset to default when the shell itself restarts.

    implicitWidth: 660
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 16

        // --- Now playing ---------------------------------------------------
        Item {
            width: parent.width
            height: Math.max(96, infoColumn.implicitHeight)

            // Album art — use the same rounded clipping primitive as the
            // wallpaper preview. ClippingRectangle keeps the source image in
            // the normal scene graph; the previous hidden Image + MultiEffect
            // mask produced an empty texture and leaked the image elsewhere.
            ClippingRectangle {
                id: albumArt
                width: 96
                height: 96
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: Colors.surfaceHigh
                border.width: 1
                border.color: Colors.overlay
                clip: true

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !(root.track && root.track.artUrl)
                    icon: "music_note"
                    font.pixelSize: 34
                    opacity: 0.7
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: !!(root.track && root.track.artUrl)
                    source: root.track && root.track.artUrl ? root.track.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Live audio visualizer — same normalized cava signal
            // IdleBump.qml's visualizer runs on (Cava.bars are raw
            // 0..Cava.maxRange values, so they get scaled to the 0..1
            // MiniVisualizer expects). Pinned to the top-right corner so it
            // doesn't compete with the title/artist text for vertical space.
            MiniVisualizer {
                id: visualizer
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                visible: root.media.playback.playing
                active: Cava.anyPlaying
                levels: visible && active ? Cava.bars.map(v => v / Cava.maxRange) : []
                barColor: Colors.accent
                maxHeight: 14
                bottomPadding: 4
                barWidth: 4
            }

            Column {
                id: infoColumn
                anchors.left: albumArt.right
                anchors.leftMargin: 16
                anchors.right: visualizer.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Config.fontSize + 6
                    text: root.track && root.track.title ? root.track.title : "Nothing playing"
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    opacity: 0.6
                    text: root.track ? root.track.artist : ""
                }

                Row {
                    spacing: 6
                    topPadding: 2
                    visible: !!root.connectedDevice || root.media.identity.length > 0

                    Rectangle {
                        visible: !!root.connectedDevice
                        width: btChip.implicitWidth + 18
                        height: 22
                        radius: 11
                        color: Colors.surfaceHigh

                        Row {
                            id: btChip
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon { icon: "bluetooth"; font.pixelSize: 12; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                            StyledText {
                                text: root.connectedDevice ? (root.connectedDevice.name || root.connectedDevice.deviceName) : ""
                                font.pixelSize: Config.fontSize - 3
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        visible: root.media.identity.length > 0
                        width: viaChip.implicitWidth + 18
                        height: 22
                        radius: 11
                        color: Colors.surfaceHigh

                        Row {
                            id: viaChip
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon { icon: "graphic_eq"; font.pixelSize: 12; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                            StyledText {
                                text: root.media.identity
                                opacity: 0.6
                                font.pixelSize: Config.fontSize - 3
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // --- Player switcher (only when more than one source is active) -----
        Row {
            width: parent.width
            spacing: 6
            visible: root.media.players.length > 1

            Repeater {
                model: root.media.players

                Chip {
                    required property var modelData
                    text: modelData.name
                    active: root.media.selectedId === modelData.id
                    onClicked: MediaSession.selectPlayer(modelData.id)
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Slider {
                width: parent.width
                trackHeight: 4
                thumbHoverOnly: true
                value: root.track && root.track.duration > 0 ? root.track.position / root.track.duration : 0
                onMoved: v => MediaSession.seek(v)
            }

            Row {
                width: parent.width
                StyledText {
                    text: root.formatTime(root.track ? root.track.position : 0)
                    font.family: Config.monoFontFamily
                    opacity: 0.7
                    font.pixelSize: Config.fontSize - 2
                }
                Item { width: parent.width - 2 * 60; height: 1 }
                StyledText {
                    text: root.formatTime(root.track ? root.track.duration : 0)
                    font.family: Config.monoFontFamily
                    opacity: 0.7
                    font.pixelSize: Config.fontSize - 2
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            IconButton {
                icon: "shuffle"
                iconSize: 17
                visible: root.media.capabilities.shuffle
                active: root.media.playback.shuffle
                anchors.verticalCenter: parent.verticalCenter
                onClicked: MediaSession.toggleShuffle()
            }
            IconButton {
                icon: "skip_previous"
                iconSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: MediaSession.previous()
            }
            IconButton {
                width: 44
                height: 44
                icon: root.media.playback.playing ? "pause" : "play_arrow"
                iconSize: 26
                active: root.media.playback.playing
                anchors.verticalCenter: parent.verticalCenter
                onClicked: MediaSession.togglePlaying()
            }
            IconButton {
                icon: "skip_next"
                iconSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: MediaSession.next()
            }
            IconButton {
                icon: root.media.playback.loop === "track" ? "repeat_one" : "repeat"
                iconSize: 17
                visible: root.media.capabilities.loop
                active: root.media.playback.loop !== "none"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: MediaSession.cycleLoop()
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.15 }

        // --- Equalizer -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 14

            Item {
                width: parent.width
                height: 22

                StyledText { text: "Equalizer"; font.bold: true; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MaterialIcon {
                        visible: Equalizer.eqIsSaved
                        icon: "check_circle"
                        filled: true
                        font.pixelSize: 14
                        color: Colors.success
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Equalizer.currentPreset.charAt(0).toUpperCase() + Equalizer.currentPreset.slice(1)
                        color: Colors.accent
                        font.bold: true
                    }
                }
            }

            Row {
                width: parent.width
                height: 110
                spacing: (parent.width - 10 * 18) / 9

                Repeater {
                    model: Equalizer.eqBandLabels

                    Column {
                        required property string modelData
                        required property int index

                        spacing: 6

                        VerticalSlider {
                            height: 78
                            value: Equalizer.eqValues[index]
                            centerValue: 0.5
                            onMoved: v => {
                                const values = Equalizer.eqValues.slice();
                                values[index] = v;
                                Equalizer.eqValues = values;
                            }
                            onReleased: Equalizer.applyLiveBands()
                        }
                        StyledText {
                            text: modelData
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.6
                            font.pixelSize: Config.fontSize - 4
                            font.family: Config.monoFontFamily
                        }
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 4
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: Object.keys(Equalizer.eqPresets)

                    Chip {
                        required property string modelData

                        width: (parent.width - 3 * 8) / 4
                        height: 32
                        active: Equalizer.currentPreset === modelData
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        onClicked: Equalizer.applyPreset(modelData)
                    }
                }
            }
        }
    }
}
