import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var player: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.find(p => p.isPlaying) || players.find(p => p.canControl) || players[0] || null;
    }

    readonly property var connectedDevice: {
        const devices = Bluetooth.devices ? Bluetooth.devices.values : [];
        return devices.find(d => d.connected) || null;
    }

    // Most players only emit positionChanged on seek/track-change, not every
    // second during normal playback — binding the seek bar straight to
    // player.position left it visibly frozen while a track played. Poll it
    // instead; a direct property read here (not inside a binding) always
    // gets the live value regardless of whether the signal fired.
    property real displayPosition: player ? player.position : 0

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {
        interval: 1000
        running: !!(root.player && root.player.isPlaying)
        repeat: true
        onTriggered: root.displayPosition = root.player.position
    }

    Connections {
        target: root.player
        function onPositionChanged() { root.displayPosition = root.player.position; }
        function onTrackTitleChanged() { root.displayPosition = root.player ? root.player.position : 0; }
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
        Row {
            width: parent.width
            spacing: 16

            // Album art — circular using OpacityMask
            Item {
                width: 96
                height: 96
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: artBg
                    anchors.fill: parent
                    radius: width / 2
                    color: Colors.surfaceHigh
                    border.width: 1
                    border.color: Colors.overlay

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !(root.player && root.player.trackArtUrl)
                        icon: "music_note"
                        font.pixelSize: 34
                        opacity: 0.7
                    }
                }

                Rectangle {
                    id: artCircleMask
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: width / 2
                    visible: false
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: false
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                OpacityMask {
                    anchors.fill: artCircleMask
                    source: artImage
                    maskSource: artCircleMask
                    visible: !!(root.player && root.player.trackArtUrl)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 96 - 16
                spacing: 6

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Config.fontSize + 6
                    text: root.player && root.player.trackTitle ? root.player.trackTitle : "Nothing playing"
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    opacity: 0.6
                    text: root.player && root.player.trackArtist ? root.player.trackArtist : ""
                }

                Row {
                    spacing: 6
                    topPadding: 2
                    visible: !!root.connectedDevice || !!(root.player && root.player.identity)

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
                        visible: !!(root.player && root.player.identity)
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
                                text: root.player ? root.player.identity : ""
                                opacity: 0.6
                                font.pixelSize: Config.fontSize - 3
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
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
                value: root.player && root.player.lengthSupported && root.player.length > 0
                    ? root.displayPosition / root.player.length : 0
                onMoved: v => {
                    if (root.player && root.player.canSeek && root.player.length > 0) {
                        const newPos = v * root.player.length;
                        root.player.position = newPos;
                        root.displayPosition = newPos;
                    }
                }
            }

            Row {
                width: parent.width
                StyledText {
                    text: root.formatTime(root.displayPosition)
                    font.family: Config.monoFontFamily
                    opacity: 0.7
                    font.pixelSize: Config.fontSize - 2
                }
                Item { width: parent.width - 2 * 60; height: 1 }
                StyledText {
                    text: root.player ? root.formatTime(root.player.length) : "00:00"
                    font.family: Config.monoFontFamily
                    opacity: 0.7
                    font.pixelSize: Config.fontSize - 2
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28

            IconButton {
                icon: "skip_previous"
                iconSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
            }
            IconButton {
                width: 44
                height: 44
                icon: root.player && root.player.isPlaying ? "pause" : "play_arrow"
                iconSize: 26
                active: !!(root.player && root.player.isPlaying)
                anchors.verticalCenter: parent.verticalCenter
                onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
            }
            IconButton {
                icon: "skip_next"
                iconSize: 19
                anchors.verticalCenter: parent.verticalCenter
                onClicked: if (root.player && root.player.canGoNext) root.player.next()
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

                    Rectangle {
                        required property string modelData
                        readonly property bool active: Equalizer.currentPreset === modelData

                        width: (parent.width - 3 * 8) / 4
                        height: 32
                        radius: height / 2
                        color: active ? Colors.accent : Colors.surfaceHigh
                        Behavior on color { ColorAnimation { duration: Config.animFast } }

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: active ? Colors.accentText : Colors.text
                            font.pixelSize: Config.fontSize - 2
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Colors.surfaceHigh
                            opacity: eqChipHover.hovered && !active ? 0.25 : 0
                        }

                        HoverHandler { id: eqChipHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Equalizer.applyPreset(modelData)
                        }
                    }
                }
            }
        }
    }
}
