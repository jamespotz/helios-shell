import QtQuick
import "../../services"
import "../../components"

// Screenshot panel — segmented mode picker, shutter button, then swaps to a
// result card (thumbnail, extracted text, quick actions) once a capture
// lands. Options (OCR, clipboard, save location) live in a shared disclosure.
Item {
    id: root

    readonly property var modes: [
        { key: Screenshot.modeFullscreen, icon: "desktop_windows", label: "Full Screen" },
        { key: Screenshot.modeRegion, icon: "crop", label: "Region" },
        { key: Screenshot.modeWindow, icon: "web_asset", label: "Window" }
    ]

    property bool manualNewCapture: false
    readonly property bool hasResult: !root.manualNewCapture && Screenshot.lastPath.length > 0
        && !Screenshot.capturing && Screenshot.lastError.length === 0
    readonly property string optionsSummary: {
        let parts = [];
        if (Screenshot.ocrEnabled) parts.push("OCR");
        if (Screenshot.copyToClipboardEnabled) parts.push("Clipboard");
        return parts.join(" · ");
    }

    Connections {
        target: Screenshot
        function onCapturingChanged() { if (Screenshot.capturing) root.manualNewCapture = false; }
    }

    // Re-check that the last capture still exists on disk each time this
    // tab is (re)opened, so a file deleted outside the shell doesn't leave
    // a stale preview behind.
    Connections {
        target: IslandNavigation
        function onOpenChanged() {
            if (IslandNavigation.open && IslandNavigation.destinationId === "screenshot") {
                Screenshot.verifyLastPath();
            }
        }
    }
    Component.onCompleted: Screenshot.verifyLastPath()

    implicitWidth: 290
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "photo_camera"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Screenshot"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        // ─── Mode selector (always visible, even over a result) ──────
        Row {
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: root.modes

                Chip {
                    id: modeChip
                    required property var modelData
                    active: Screenshot.mode === modelData.key
                    text: modelData.label
                    enabled: !Screenshot.capturing
                    onClicked: Screenshot.mode = modeChip.modelData.key

                    MaterialIcon {
                        icon: modeChip.modelData.icon
                        font.pixelSize: 14
                        color: modeChip.active ? Colors.accentText : Colors.text
                    }
                }
            }
        }

        // ─── Shutter (idle) ───────────────────────────────────────────
        Column {
            visible: !root.hasResult
            width: parent.width
            spacing: 14

            Item {
                width: parent.width
                height: 80

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

                    Rectangle {
                        id: shutterInner
                        anchors.centerIn: parent
                        width: Screenshot.capturing ? 24 : 56
                        height: width
                        radius: Screenshot.capturing ? 6 : 28
                        color: Colors.accent
                        Behavior on width { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
                        Behavior on radius { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }

                        scale: captureHover.hovered ? 0.92 : 1.0
                        Behavior on scale { NumberAnimation { duration: Config.animFast } }
                    }

                    HoverHandler { id: captureHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !Screenshot.capturing
                        onClicked: Screenshot.capture(Screenshot.mode)
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Config.fontSize - 1
                color: Screenshot.lastError.length > 0 ? Colors.danger : Colors.subtext
                text: Screenshot.capturing ? "Capturing…"
                    : Screenshot.lastError.length > 0 ? Screenshot.lastError
                    : "Click to capture · ↵"
                opacity: 0.85
            }
        }

        // ─── Result card (post-capture) ──────────────────────────────
        Column {
            visible: root.hasResult
            width: parent.width
            spacing: 10

            Rectangle {
                width: parent.width
                height: 140
                radius: Colors.radiusSmall
                color: Colors.surface
                clip: true

                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: root.hasResult ? "file://" + Screenshot.lastPath : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            Item {
                width: parent.width
                height: Math.max(fileNameLabel.implicitHeight, resLabel.implicitHeight)

                StyledText {
                    id: fileNameLabel
                    anchors.left: parent.left
                    anchors.right: resLabel.left
                    anchors.rightMargin: 8
                    elide: Text.ElideMiddle
                    font.pixelSize: Config.fontSize - 2
                    opacity: 0.7
                    text: Screenshot.lastPath.split("/").pop()
                }

                StyledText {
                    id: resLabel
                    anchors.right: parent.right
                    font.pixelSize: Config.fontSize - 2
                    opacity: 0.5
                    text: previewImage.status === Image.Ready
                        ? previewImage.sourceSize.width + " × " + previewImage.sourceSize.height
                        : ""
                }
            }

            // ─── Extracted text card ────────────────────────────────
            Rectangle {
                visible: Screenshot.ocrEnabled && Screenshot.extractedText.length > 0
                width: parent.width
                height: extractedCol.implicitHeight + 20
                radius: Colors.radiusSmall
                color: Colors.surface

                Column {
                    id: extractedCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    spacing: 6

                    Row {
                        spacing: 5
                        MaterialIcon { icon: "text_fields"; font.pixelSize: 13; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "EXTRACTED TEXT"
                            font.pixelSize: Config.fontSize - 3
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                            opacity: 0.6
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: Screenshot.extractedText
                        font.pixelSize: Config.fontSize - 2
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                }
            }

            // ─── Actions ─────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 8

                PrimaryButton {
                    width: (parent.width - folderBtn.width - 16) * 0.6
                    height: 40
                    text: "New capture"
                    icon: "photo_camera"
                    active: true
                    onClicked: root.manualNewCapture = true
                }

                PrimaryButton {
                    width: (parent.width - folderBtn.width - 16) * 0.4
                    height: 40
                    text: "Copy"
                    icon: "content_copy"
                    onClicked: Screenshot.copyLast()
                }

                IconButton {
                    id: folderBtn
                    width: 40
                    height: 40
                    icon: "folder_open"
                    onClicked: Screenshot.openFolder()
                }
            }
        }

        // ─── Options ─────────────────────────────────────────────────
        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.12 }

        Disclosure {
            width: parent.width
            summary: root.optionsSummary

            ToggleRow {
                width: parent.width
                icon: "text_fields"
                title: "Extract text (OCR)"
                subtitle: "Reads text from the capture"
                checked: Screenshot.ocrEnabled
                onToggled: v => Screenshot.ocrEnabled = v
            }

            ToggleRow {
                width: parent.width
                icon: "content_copy"
                title: "Copy to clipboard"
                subtitle: "Alongside saving the file"
                checked: Screenshot.copyToClipboardEnabled
                onToggled: v => Screenshot.copyToClipboardEnabled = v
            }

            Column {
                width: parent.width
                spacing: 6

                StyledText { text: "Save to"; font.pixelSize: Config.fontSize - 2; opacity: 0.6 }

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width - changeBtn.width - 8
                        height: 34
                        radius: Colors.radiusSmall
                        color: Colors.surface

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 10
                            spacing: 6

                            MaterialIcon { icon: "folder_open"; font.pixelSize: 14; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                            StyledText {
                                width: parent.width - 20
                                elide: Text.ElideMiddle
                                font.pixelSize: Config.fontSize - 2
                                opacity: 0.7
                                text: Screenshot.outputDir
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    PrimaryButton {
                        id: changeBtn
                        height: 34
                        text: "Change"
                        onClicked: Screenshot.chooseOutputDir()
                    }
                }
            }
        }
    }
}
