import QtQuick
import "../../services"
import "../../components"

// Screenshot panel — three capture modes (fullscreen, region, window)
// with status feedback and quick access to the last capture.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "screenshot_monitor"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Screenshot"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        // Capture mode buttons — three large pill buttons
        Column {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: fullHover.hovered ? Colors.surfaceHigh : Colors.surface
                opacity: fullHover.hovered ? 0.8 : 0.5
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    MaterialIcon { icon: "monitor"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Capture Full Screen"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: fullHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Bridge.closeIsland(); Screenshot.captureFullscreen(); }
                }
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: regionHover.hovered ? Colors.surfaceHigh : Colors.surface
                opacity: regionHover.hovered ? 0.8 : 0.5
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    MaterialIcon { icon: "crop"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Capture Region"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: regionHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Bridge.closeIsland(); Screenshot.captureRegion(); }
                }
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: winHover.hovered ? Colors.surfaceHigh : Colors.surface
                opacity: winHover.hovered ? 0.8 : 0.5
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    MaterialIcon { icon: "web_asset"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Capture Active Window"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: winHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Bridge.closeIsland(); Screenshot.captureWindow(); }
                }
            }
        }

        // Status feedback
        Rectangle {
            visible: Screenshot.lastCopied || Screenshot.lastError.length > 0
            width: parent.width
            height: statusCol.implicitHeight + 16
            radius: 10
            color: Screenshot.lastError.length > 0 ? Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.15)
                : Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.15)

            Column {
                id: statusCol
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 4

                Row {
                    spacing: 6
                    MaterialIcon {
                        icon: Screenshot.lastError.length > 0 ? "error" : "check_circle"
                        font.pixelSize: 16
                        color: Screenshot.lastError.length > 0 ? Colors.danger : Colors.success
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Screenshot.lastError.length > 0 ? "Failed" : "Copied to clipboard"
                        font.weight: Font.Medium
                        color: Screenshot.lastError.length > 0 ? Colors.danger : Colors.success
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    visible: Screenshot.lastError.length > 0
                    text: Screenshot.lastError
                    font.pixelSize: Config.fontSize - 2
                    color: Colors.subtext
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Quick actions for last screenshot
        Row {
            visible: Screenshot.lastPath.length > 0 && Screenshot.lastCopied
            spacing: 8

            Rectangle {
                width: openFileContent.implicitWidth + 16
                height: 30
                radius: 15
                color: openFileHover.hovered ? Colors.surfaceHigh : "transparent"

                Row {
                    id: openFileContent
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialIcon { icon: "open_in_new"; font.pixelSize: 14; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Open"; font.pixelSize: Config.fontSize - 1; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: openFileHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Screenshot.openLast() }
            }

            Rectangle {
                width: openFolderContent.implicitWidth + 16
                height: 30
                radius: 15
                color: openFolderHover.hovered ? Colors.surfaceHigh : "transparent"

                Row {
                    id: openFolderContent
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialIcon { icon: "folder_open"; font.pixelSize: 14; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Show in Folder"; font.pixelSize: Config.fontSize - 1; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: openFolderHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Screenshot.openFolder() }
            }
        }
    }
}
