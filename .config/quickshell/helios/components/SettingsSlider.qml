import QtQuick
import "../services"

// Slider row inside a SettingsCard: icon + label, slider, formatted value.
Item {
    id: root
    property string icon: ""
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property var format: v => Math.round(v) + " px"
    property bool last: false

    signal moved(real value)

    width: parent ? parent.width : 0
    height: 48

    Row {
        id: sliderLabel
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 150
        spacing: 10

        MaterialIcon { icon: root.icon; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: root.label; anchors.verticalCenter: parent.verticalCenter }
    }

    Slider {
        anchors.left: sliderLabel.right
        anchors.right: valueLabel.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        label: root.label
        trackColor: Colors.surface
        value: root.value - root.from
        maxValue: root.to - root.from
        onMoved: v => root.moved(root.from + v)
    }

    StyledText {
        id: valueLabel
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 56
        horizontalAlignment: Text.AlignRight
        text: root.format(root.value)
        color: Colors.subtext
    }

    Rectangle {
        visible: !root.last
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.bottom: parent.bottom
        height: 1
        color: Colors.overlay
        opacity: 0.15
    }
}
