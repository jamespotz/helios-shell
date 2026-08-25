import QtQuick
import "../../services"
import "../../components"

// Screenshot panel — Apple-style capture UI with segmented mode picker,
// prominent capture button, animated status toast, and quick-action chips.
Item {
    id: root

    readonly property var modes: [
        { key: Screenshot.modeFullscreen, icon: "desktop_windows", label: "Full Screen" },
        { key: Screenshot.modeRegion, icon: "crop", label: "Region" },
        { key: Screenshot.modeWindow, icon: "web_asset", label: "Window" }
    ]

    implicitWidth: 290
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // ─── Segmented mode selector ─────────────────────────────────
        // Pill-shaped chip row, mirrors ScreenRecorderTab's pattern.
        Row {
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: root.modes

                delegate: Rectangle {
                    id: modeBtn
                    required property var modelData
                    readonly property bool isActive: Screenshot.mode === modelData.key

                    width: modeContent.implicitWidth + 18
                    height: 28
                    radius: height / 2
                    color: isActive ? Colors.accent : Colors.surfaceHigh
                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    // Hover overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: modeHover.hovered && !modeBtn.isActive ? 0.25 : 0
                        Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                    }

                    HoverHandler { id: modeHover }

                    Row {
                        id: modeContent
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            icon: modeBtn.modelData.icon
                            font.pixelSize: 14
                            color: modeBtn.isActive ? Colors.accentText : Colors.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: modeBtn.modelData.label
                            font.pixelSize: Config.fontSize - 2
                            font.weight: Font.Medium
                            color: modeBtn.isActive ? Colors.accentText : Colors.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !Screenshot.capturing
                        onClicked: Screenshot.mode = modeBtn.modelData.key
                    }
                }
            }
        }

        // ─── Capture button ──────────────────────────────────────────
        // Large circular shutter button, Apple Camera-style.
        Item {
            width: parent.width
            height: 80

            // Outer ring
            Rectangle {
                id: shutterRing
                anchors.centerIn: parent
                width: 68
                height: 68
                radius: 34
                color: "transparent"
                border.width: 3
                border.color: Screenshot.capturing ? Colors.overlay : Colors.accent
                Behavior on border.color { ColorAnimation { duration: Config.animMedium } }

                // Inner filled circle
                Rectangle {
                    id: shutterInner
                    anchors.centerIn: parent
                    width: Screenshot.capturing ? 24 : 56
                    height: width
                    radius: Screenshot.capturing ? 6 : 28
                    color: Colors.accent
                    Behavior on width { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
                    Behavior on radius { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }

                    // Subtle scale on hover
                    scale: captureHover.hovered ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: Config.animFast } }
                }

                HoverHandler { id: captureHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Screenshot.capturing
                    onClicked: {
                        Bridge.closeIsland();
                        Screenshot.capture(Screenshot.mode);
                    }
                }
            }
        }

        // ─── Status label ────────────────────────────────────────────
        // Minimal centered text: idle hint or capture result.
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Config.fontSize - 1
            color: Screenshot.capturing ? Colors.subtext
                 : Screenshot.lastError.length > 0 ? Colors.danger
                 : Screenshot.lastCopied ? Colors.success
                 : Colors.subtext
            text: Screenshot.capturing ? "Capturing…"
                : Screenshot.lastError.length > 0 ? Screenshot.lastError
                : Screenshot.lastCopied ? "Saved to clipboard"
                : "Tap to capture"
            opacity: 0.85
            Behavior on color { ColorAnimation { duration: Config.animFast } }
        }

        // ─── Status toast (success/error) ────────────────────────────
        // Slides in after capture with result + quick actions.
        Rectangle {
            id: statusCard
            visible: Screenshot.lastCopied || Screenshot.lastError.length > 0
            width: parent.width
            height: statusContent.implicitHeight + 20
            radius: Colors.radiusSmall
            color: Screenshot.lastError.length > 0
                ? Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.12)
                : Qt.rgba(Colors.success.r, Colors.success.g, Colors.success.b, 0.10)
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.animMedium } }

            Column {
                id: statusContent
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 10

                // Result row
                Row {
                    spacing: 7
                    MaterialIcon {
                        icon: Screenshot.lastError.length > 0 ? "error_outline" : "check_circle"
                        font.pixelSize: 16
                        color: Screenshot.lastError.length > 0 ? Colors.danger : Colors.success
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Screenshot.lastError.length > 0 ? "Capture failed" : "Screenshot saved"
                        font.weight: Font.Medium
                        font.pixelSize: Config.fontSize
                        color: Screenshot.lastError.length > 0 ? Colors.danger : Colors.success
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Error detail
                StyledText {
                    visible: Screenshot.lastError.length > 0
                    text: Screenshot.lastError
                    font.pixelSize: Config.fontSize - 2
                    color: Colors.subtext
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                // Quick-action chips
                Row {
                    visible: Screenshot.lastPath.length > 0 && Screenshot.lastCopied
                    spacing: 8

                    // Open file chip
                    Rectangle {
                        width: openRow.implicitWidth + 14
                        height: 28
                        radius: height / 2
                        color: openChipHover.hovered ? Colors.surfaceHigh : Colors.surface
                        Behavior on color { ColorAnimation { duration: Config.animFast } }

                        Row {
                            id: openRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon { icon: "open_in_new"; font.pixelSize: 13; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "Open"; font.pixelSize: Config.fontSize - 2; color: Colors.accent; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }

                        HoverHandler { id: openChipHover }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Screenshot.openLast() }
                    }

                    // Show in folder chip
                    Rectangle {
                        width: folderRow.implicitWidth + 14
                        height: 28
                        radius: height / 2
                        color: folderChipHover.hovered ? Colors.surfaceHigh : Colors.surface
                        Behavior on color { ColorAnimation { duration: Config.animFast } }

                        Row {
                            id: folderRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIcon { icon: "folder_open"; font.pixelSize: 13; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "Folder"; font.pixelSize: Config.fontSize - 2; color: Colors.accent; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }

                        HoverHandler { id: folderChipHover }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Screenshot.openFolder() }
                    }
                }
            }
        }

        // ─── Separator ───────────────────────────────────────────────
        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.12 }

        // ─── Output path link ────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 7

            MaterialIcon { icon: "folder_open"; font.pixelSize: 14; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }

            StyledText {
                width: parent.width - 24
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                opacity: pathHover.hovered ? 1 : 0.6
                font.pixelSize: Config.fontSize - 2
                font.underline: pathHover.hovered
                text: Screenshot.lastPath || Screenshot.outputDir
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                MouseArea {
                    id: pathHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Screenshot.openFolder()
                }
            }
        }
    }
}
