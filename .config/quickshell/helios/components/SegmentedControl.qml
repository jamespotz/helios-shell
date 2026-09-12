import QtQuick
import "../services"

// Evenly-divided segmented switch — a shared track with an accent-filled
// active segment (e.g. Output/Input, Wi-Fi/Bluetooth mode toggles).
// model entries: { value, label, icon }.
Rectangle {
    id: root

    property var model: []
    property var currentValue: null

    signal activated(var value)

    implicitHeight: 36
    implicitWidth: _naturalTotal + 6
    radius: height / 2
    color: Colors.surfaceHigh

    // Segments size to their own label first, so a long option like
    // "Background" never clips. Leftover width splits evenly.
    FontMetrics {
        id: fontMetrics
        font.family: Config.fontFamily
        font.pixelSize: Config.fontSize
        font.letterSpacing: -0.2
    }
    readonly property var _naturalWidths: root.model.map(m => fontMetrics.advanceWidth(m.label) + (m.icon ? 24 : 0) + 28)
    readonly property real _naturalTotal: _naturalWidths.reduce((a, b) => a + b, 0)

    Row {
        id: track
        anchors.fill: parent
        anchors.margins: 3

        Repeater {
            model: root.model

            Rectangle {
                id: segment
                required property var modelData
                required property int index
                readonly property bool active: root.currentValue === segment.modelData.value

                width: root._naturalWidths[segment.index] + Math.max(0, track.width - root._naturalTotal) / root.model.length
                height: parent.height
                radius: height / 2
                scale: Config.reducedMotion ? 1 : segmentMouse.pressed ? 0.94 : 1
                color: segment.active ? Colors.accent : (segHover.hovered ? Colors.surface : "transparent")

                Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Config.reducedMotion ? 0 : Config.animFast; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        visible: !!segment.modelData.icon
                        icon: segment.modelData.icon || ""
                        font.pixelSize: 15
                        color: segment.active ? Colors.accentText : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: segment.modelData.label
                        color: segment.active ? Colors.accentText : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Focus ring — keyboard-navigation feedback
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.accent
                    visible: segment.activeFocus
                }

                HoverHandler { id: segHover }

                MouseArea {
                    id: segmentMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(segment.modelData.value)
                }

                activeFocusOnTab: true
                Keys.onReturnPressed: root.activated(segment.modelData.value)
                Keys.onSpacePressed: root.activated(segment.modelData.value)
            }
        }
    }
}
