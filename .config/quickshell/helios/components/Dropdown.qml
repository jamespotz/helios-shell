import QtQuick
import "../services"

// Row-based enum picker — click to expand an inline option list, matching
// DefaultAppsIsland's collapsed-row-expands-to-picker interaction rather
// than a native ComboBox popup, so it looks like the rest of Settings.
Column {
    id: root

    property string label: ""
    property var model: []          // [{ value, label }]
    property var currentValue: null

    signal activated(var value)

    property bool open: false

    readonly property var currentLabel: {
        const m = root.model.find(o => o.value === root.currentValue);
        return m ? m.label : String(root.currentValue);
    }

    width: parent ? parent.width : 0
    spacing: 4

    Row {
        width: parent.width
        height: 36

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            text: root.label
            opacity: 0.7
            font.pixelSize: Config.fontSize - 2
        }

        Rectangle {
            width: parent.width - 90
            height: 32
            radius: height / 2
            color: Colors.surface
            anchors.verticalCenter: parent.verticalCenter

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width - 16
                    text: root.currentLabel
                    elide: Text.ElideRight
                }
                MaterialIcon {
                    icon: root.open ? "expand_less" : "expand_more"
                    font.pixelSize: 14
                    opacity: 0.7
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open = !root.open
            }
        }
    }

    Column {
        visible: root.open
        width: parent.width
        spacing: 1

        Repeater {
            model: root.model

            Rectangle {
                id: optionDelegate
                required property var modelData
                width: parent.width
                height: 32
                radius: Colors.radiusSmall
                color: optionHover.hovered ? Colors.surfaceHigh : "transparent"

                HoverHandler { id: optionHover }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: optionDelegate.modelData.label
                    color: optionDelegate.modelData.value === root.currentValue ? Colors.accent : Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activated(optionDelegate.modelData.value);
                        root.open = false;
                    }
                }
            }
        }
    }
}
