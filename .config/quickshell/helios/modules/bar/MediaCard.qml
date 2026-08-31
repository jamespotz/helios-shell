import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var activePlayers: Mpris.players ? Mpris.players.values : []
    property string selectedPlayerId: ""
    readonly property var player: MprisHelpers.selectPlayer(root.activePlayers, root.selectedPlayerId)

    // Drop a pinned selection once that player disappears (app closed, dbus
    // name released) instead of silently freezing on a dead player.
    onActivePlayersChanged: {
        if (root.selectedPlayerId && !root.activePlayers.some(p => p.dbusName === root.selectedPlayerId)) {
            root.selectedPlayerId = "";
        }
    }

    readonly property var connectedDevice: Bluetooth.devices.find(d => d.connected) || null

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
                    visible: !(root.player && root.player.trackArtUrl)
                    icon: "music_note"
                    font.pixelSize: 34
                    opacity: 0.7
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: !!(root.player && root.player.trackArtUrl)
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
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
                visible: !!(root.player && root.player.isPlaying)
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

        // --- Player switcher (only when more than one source is active) -----
        Row {
            width: parent.width
            spacing: 6
            visible: root.activePlayers.length > 1

            Repeater {
                model: root.activePlayers

                Chip {
                    required property var modelData
                    text: modelData.identity || "Player"
                    active: !!(root.player && root.player.dbusName === modelData.dbusName)
                    onClicked: root.selectedPlayerId = modelData.dbusName
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
            spacing: 20

            IconButton {
                icon: "shuffle"
                iconSize: 17
                visible: !!(root.player && root.player.shuffleSupported)
                active: !!(root.player && root.player.shuffle)
                anchors.verticalCenter: parent.verticalCenter
                onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
            }
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
            IconButton {
                icon: root.player && root.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                iconSize: 17
                visible: !!(root.player && root.player.loopSupported)
                active: !!(root.player && root.player.loopState !== MprisLoopState.None)
                anchors.verticalCenter: parent.verticalCenter
                onClicked: if (root.player) root.player.loopState = MprisHelpers.nextLoopState(root.player.loopState)
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
