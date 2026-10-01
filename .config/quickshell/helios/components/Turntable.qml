import QtQuick
import Quickshell.Widgets
import "../services"

// A record player showing the track's cover art as the record label.
// Playing spins the platter up to 33⅓ rpm and cues the tonearm onto the
// lead-in groove; the arm then tracks inward with playback progress. Pausing
// lifts the arm back to its rest and lets the platter coast to a stop.
// Reduced motion keeps the record still and moves the arm without easing.
Item {
    id: root

    property string artUrl: ""
    property bool playing: false
    // 0 at the start of the track, 1 at the end.
    property real progress: 0
    // Record diameter; the plinth around it scales from this.
    property real size: 160

    readonly property real _pad: root.size * 0.08
    readonly property real _platterSize: root.size * 1.04
    readonly property real _armLength: root.size * 0.86
    // Arm angles (clockwise from pointing down) for the rest post, the
    // lead-in groove, and the run-out near the label.
    readonly property real _restAngle: 0
    readonly property real _leadInAngle: 27
    readonly property real _runOutAngle: 40

    implicitWidth: root._pad + root._platterSize + root.size * 0.32
    implicitHeight: root._pad * 2 + root._platterSize

    // 0 = stopped, 1 = full speed. Eased so the platter spins up and coasts
    // down instead of snapping.
    property real _speed: root.playing && !Config.reducedMotion ? 1 : 0
    Behavior on _speed {
        NumberAnimation {
            duration: root.playing ? 900 : 1800
            easing.type: root.playing ? Easing.InOutSine : Easing.OutCubic
        }
    }

    // 33⅓ rpm = 200°/s. Only ticks while the platter is moving.
    FrameAnimation {
        running: root._speed > 0.001 && root.visible
        onTriggered: record.rotation = (record.rotation + frameTime * 200 * root._speed) % 360
    }

    Rectangle {
        id: plinth
        anchors.fill: parent
        radius: Colors.radiusLarge
        color: Colors.surfaceHigh
    }

    // Platter mat, slightly wider than the record.
    Rectangle {
        id: platter
        x: root._pad
        y: root._pad
        width: root._platterSize
        height: width
        radius: width / 2
        color: Colors.surface

        Rectangle {
            id: record
            anchors.centerIn: parent
            width: root.size
            height: width
            radius: width / 2
            // Vinyl stays black whatever the theme.
            color: "#111113"
            antialiasing: true

            // Grooves.
            Repeater {
                model: 6
                Rectangle {
                    id: groove
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * (0.92 - groove.index * 0.085)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, groove.index % 2 ? 0.04 : 0.07)
                }
            }

            // Label: the cover art, or an accent label with a note.
            ClippingRectangle {
                anchors.centerIn: parent
                width: record.width * 0.42
                height: width
                radius: width / 2
                color: Colors.accent

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    icon: "music_note"
                    font.pixelSize: parent.width * 0.4
                    color: Colors.accentText
                }

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }

            // Spindle.
            Rectangle {
                anchors.centerIn: parent
                width: record.width * 0.035
                height: width
                radius: width / 2
                color: Colors.surface
            }
        }
    }

    // Tonearm base.
    Rectangle {
        x: tonearm.x - width / 2
        y: tonearm.y - height / 2
        width: root.size * 0.17
        height: width
        radius: width / 2
        color: Colors.surface

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.5
            height: width
            radius: width / 2
            color: Colors.overlay
        }
    }

    // Zero-size pivot; the arm hangs down from it and swings clockwise
    // toward the record.
    Item {
        id: tonearm
        x: root.width - root.size * 0.14
        y: root._pad + root.size * 0.1
        rotation: root.playing
            ? root._leadInAngle + Math.max(0, Math.min(1, root.progress)) * (root._runOutAngle - root._leadInAngle)
            : root._restAngle
        Behavior on rotation {
            enabled: !Config.reducedMotion
            NumberAnimation { duration: 800; easing.type: Easing.InOutCubic }
        }

        // Counterweight behind the pivot.
        Rectangle {
            x: -width / 2
            y: -root.size * 0.16
            width: root.size * 0.07
            height: root.size * 0.1
            radius: width * 0.3
            color: Colors.overlay
        }

        Rectangle {
            x: -width / 2
            y: 0
            width: Math.max(2, root.size * 0.022)
            height: root._armLength
            radius: width / 2
            color: Colors.subtext
            antialiasing: true
        }

        // Headshell at the tip.
        Rectangle {
            x: -width / 2
            y: root._armLength - height * 0.6
            width: root.size * 0.06
            height: root.size * 0.1
            radius: width * 0.25
            color: Colors.text
            antialiasing: true
        }
    }
}
