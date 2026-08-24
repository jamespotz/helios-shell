import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
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
    readonly property string eqScriptPath: Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/easyeffects-eq.py"
    readonly property var eqBandLabels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property var eqPresets: ({
        flat:    [0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50],
        bass:    [0.90, 0.85, 0.75, 0.65, 0.55, 0.45, 0.40, 0.35, 0.30, 0.30],
        pop:     [0.40, 0.45, 0.55, 0.65, 0.70, 0.65, 0.55, 0.50, 0.50, 0.55],
        rock:    [0.70, 0.65, 0.50, 0.40, 0.45, 0.55, 0.65, 0.70, 0.70, 0.65],
        treble:  [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.75, 0.85, 0.90, 0.90],
        vocal:   [0.35, 0.40, 0.50, 0.65, 0.75, 0.75, 0.65, 0.50, 0.45, 0.40],
        jazz:    [0.55, 0.50, 0.45, 0.50, 0.60, 0.60, 0.50, 0.45, 0.50, 0.55],
        classic: [0.50, 0.50, 0.50, 0.55, 0.55, 0.50, 0.50, 0.50, 0.55, 0.60]
    })
    property string currentPreset: "treble"
    property var eqValues: eqPresets["treble"].slice()

    readonly property bool eqIsSaved: {
        const p = eqValues, preset = eqPresets[currentPreset];
        if (!preset) return false;
        for (let i = 0; i < preset.length; i++) {
            if (Math.abs(preset[i] - p[i]) > 0.001) return false;
        }
        return true;
    }

    function applyPreset(name) {
        root.currentPreset = name;
        root.eqValues = root.eqPresets[name].slice();
        const presetName = name.charAt(0).toUpperCase() + name.slice(1);
        eqLoadPresetProc.command = ["flatpak", "run", "com.github.wwmm.easyeffects", "--load-preset", presetName];
        eqLoadPresetProc.running = true;
    }

    // One of these per band-drag release, not per drag frame — each call
    // shells out to `flatpak run`, too slow to fire continuously.
    function applyLiveBands() {
        const args = root.eqValues.map(v => String((v - 0.5) * 24));
        eqLiveApplyProc.command = ["python3", root.eqScriptPath].concat(args);
        eqLiveApplyProc.running = true;
    }

    Process { id: eqLoadPresetProc }
    Process { id: eqLiveApplyProc }

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

            Rectangle {
                width: 96
                height: 96
                radius: 48
                color: Colors.surfaceHigh
                border.width: 2
                border.color: Colors.accent
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    visible: !!(root.player && root.player.trackArtUrl)
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !(root.player && root.player.trackArtUrl)
                    icon: "music_note"
                    font.pixelSize: 32
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
                    font.pixelSize: Config.fontSize + 5
                    text: root.player && root.player.trackTitle ? root.player.trackTitle : "Nothing playing"
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    opacity: 0.65
                    text: root.player && root.player.trackArtist ? "BY " + root.player.trackArtist : ""
                }

                Row {
                    spacing: 8
                    visible: !!root.connectedDevice || !!(root.player && root.player.identity)

                    Rectangle {
                        visible: !!root.connectedDevice
                        width: btChip.implicitWidth + 20
                        height: 22
                        radius: 11
                        color: Colors.surfaceHigh

                        Row {
                            id: btChip
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon { icon: "bluetooth"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            StyledText {
                                text: root.connectedDevice ? (root.connectedDevice.name || root.connectedDevice.deviceName) : ""
                                font.pixelSize: Config.fontSize - 3
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!(root.player && root.player.identity)
                        text: "VIA " + (root.player ? root.player.identity : "")
                        opacity: 0.5
                        font.pixelSize: Config.fontSize - 3
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Slider {
                width: parent.width
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
                iconSize: 22
                onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
            }
            IconButton {
                icon: root.player && root.player.isPlaying ? "pause" : "play_arrow"
                iconSize: 22
                active: !!(root.player && root.player.isPlaying)
                onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
            }
            IconButton {
                icon: "skip_next"
                iconSize: 22
                onClicked: if (root.player && root.player.canGoNext) root.player.next()
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.4 }

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
                    spacing: 8

                    Rectangle {
                        visible: root.eqIsSaved
                        width: savedLabel.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: Colors.surfaceHigh
                        StyledText { id: savedLabel; anchors.centerIn: parent; text: "Saved"; font.pixelSize: Config.fontSize - 3 }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentPreset.charAt(0).toUpperCase() + root.currentPreset.slice(1)
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
                    model: root.eqBandLabels

                    Column {
                        required property string modelData
                        required property int index

                        spacing: 6

                        VerticalSlider {
                            height: 78
                            value: root.eqValues[index]
                            onMoved: v => {
                                const values = root.eqValues.slice();
                                values[index] = v;
                                root.eqValues = values;
                            }
                            onReleased: root.applyLiveBands()
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
                    model: Object.keys(root.eqPresets)

                    Rectangle {
                        required property string modelData
                        readonly property bool active: root.currentPreset === modelData

                        width: (parent.width - 3 * 8) / 4
                        height: 32
                        radius: Colors.radiusSmall
                        color: active ? Colors.accent : Colors.surfaceHigh
                        Behavior on color { ColorAnimation { duration: Config.animFast } }

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: active ? Colors.accentText : Colors.text
                            font.pixelSize: Config.fontSize - 2
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyPreset(modelData)
                        }
                    }
                }
            }
        }
    }
}
