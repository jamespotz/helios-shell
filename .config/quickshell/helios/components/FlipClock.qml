import QtQuick
import Quickshell
import "../services"

// Live clock text where each character that changes rolls up into place,
// so only the digit that ticked (second, minute, hour) moves. Ticks per
// second only when the format shows seconds.
Row {
    id: root

    property string format: Config.timeFormat
    property int pixelSize: Config.fontSize
    property int weight: Font.Normal
    property color color: Colors.text

    readonly property string text: Qt.formatDateTime(clock.date, format)

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    SystemClock {
        id: clock
        precision: /s/.test(root.format) ? SystemClock.Seconds : SystemClock.Minutes
    }

    Repeater {
        model: root.text.length

        Item {
            id: slot

            required property int index
            readonly property string ch: root.text.charAt(index)
            property string shown: ch
            // The first ch change arrives while the delegate is still being
            // set up (re-created whenever the Island switches idle ↔ peek);
            // only roll for real ticks after that.
            property bool ready: false

            width: incoming.implicitWidth
            height: incoming.implicitHeight
            clip: roll.running

            Component.onCompleted: ready = true
            onChChanged: {
                outgoing.text = shown;
                shown = ch;
                if (!ready || Config.reducedMotion)
                    return;
                roll.restart();
            }

            StyledText {
                id: outgoing
                opacity: 0
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                font.features: { "tnum": 1 }
                color: root.color
            }

            StyledText {
                id: incoming
                text: slot.shown
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                font.features: { "tnum": 1 }
                color: root.color
            }

            ParallelAnimation {
                id: roll
                NumberAnimation { target: incoming; property: "y"; from: slot.height; to: 0; duration: Config.animMedium; easing.type: Easing.OutCubic }
                NumberAnimation { target: incoming; property: "opacity"; from: 0; to: 1; duration: Config.animMedium; easing.type: Easing.OutCubic }
                NumberAnimation { target: outgoing; property: "y"; from: 0; to: -slot.height; duration: Config.animMedium; easing.type: Easing.OutCubic }
                NumberAnimation { target: outgoing; property: "opacity"; from: 1; to: 0; duration: Config.animMedium; easing.type: Easing.OutCubic }
            }
        }
    }
}
