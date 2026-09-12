import QtQuick
import "../../services"
import "../../components"

// Screen recording controls for the expanded island — start/stop
// gpu-screen-recorder, show elapsed time while running, and jump to the
// output folder once done.
Item {
    id: root

    readonly property var modes: [
        { key: ScreenRecorder.modeFullscreen, icon: "desktop_windows", label: "Full Screen" },
        { key: ScreenRecorder.modeWindow, icon: "web_asset", label: "Window / App" },
        { key: ScreenRecorder.modeRegion, icon: "crop", label: "Custom Area" }
    ]

    property bool manualNewCapture: false
    readonly property bool hasResult: !root.manualNewCapture && !ScreenRecorder.recording
        && !ScreenRecorder.starting && ScreenRecorder.lastOutputPath.length > 0

    Connections {
        target: ScreenRecorder
        function onRecordingChanged() { if (ScreenRecorder.recording) root.manualNewCapture = false; }
    }

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "videocam"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Screen Recorder"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        Row {
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: root.modes

                Chip {
                    id: modeChip
                    required property var modelData
                    active: ScreenRecorder.mode === modelData.key
                    text: modelData.label
                    enabled: !ScreenRecorder.recording && !ScreenRecorder.starting
                    onClicked: ScreenRecorder.setMode(modeChip.modelData.key)

                    MaterialIcon {
                        icon: modeChip.modelData.icon
                        font.pixelSize: 13
                        color: modeChip.active ? Colors.accentText : Colors.text
                    }
                }
            }
        }

        // ─── Recording controls (idle/active) ──────────────────────────
        Column {
            visible: !root.hasResult
            width: parent.width
            spacing: 14

            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    visible: ScreenRecorder.recording
                    width: 10
                    height: 10
                    radius: 5
                    color: Colors.danger
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: ScreenRecorder.recording
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.25; duration: 600 }
                        NumberAnimation { from: 0.25; to: 1; duration: 600 }
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Config.fontSize + 4
                    text: ScreenRecorder.recording ? ScreenRecorder.elapsedLabel
                        : ScreenRecorder.starting ? "Starting…" : "Not recording"
                }
            }

            Rectangle {
                width: 64
                height: 64
                radius: 32
                anchors.horizontalCenter: parent.horizontalCenter
                color: ScreenRecorder.recording ? Colors.surfaceHigh : Colors.accent

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: ScreenRecorder.recording ? "stop" : "fiber_manual_record"
                    filled: true
                    font.pixelSize: 26
                    color: ScreenRecorder.recording ? Colors.accent : Colors.accentText
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.surfaceHigh
                    opacity: recordHover.hovered ? 0.2 : 0
                }

                HoverHandler { id: recordHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !ScreenRecorder.starting
                    onClicked: {
                        // The island keeps a HyprlandFocusGrab active while open
                        // (Bar.qml, for "click outside closes it"), which was
                        // contesting the pointer against slurp's own region-select
                        // grab and swallowing the drag before slurp ever saw it —
                        // that's what made Custom Area look like it did nothing.
                        // Closing the island first (for every mode, not just
                        // region — the portal picker and gsr itself shouldn't have
                        // to fight it either) releases that grab before capture
                        // starts.
                        const screen = IslandNavigation.screen;
                        const startingNew = !ScreenRecorder.recording;
                        if (startingNew) IslandNavigation.close();
                        ScreenRecorder.toggle(screen);
                    }
                }
            }
        }

        // ─── Result card (post-recording) ─────────────────────────────
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
                    anchors.fill: parent
                    source: ScreenRecorder.lastThumbnailPath.length > 0 ? "file://" + ScreenRecorder.lastThumbnailPath : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: ScreenRecorder.lastThumbnailPath.length === 0
                    icon: "movie"
                    font.pixelSize: 32
                    opacity: 0.3
                }
            }

            Item {
                width: parent.width
                height: Math.max(fileNameLabel.implicitHeight, durationLabel.implicitHeight)

                StyledText {
                    id: fileNameLabel
                    anchors.left: parent.left
                    anchors.right: durationLabel.left
                    anchors.rightMargin: 8
                    elide: Text.ElideMiddle
                    font.pixelSize: Config.fontSize - 2
                    opacity: 0.7
                    text: ScreenRecorder.lastOutputPath.split("/").pop()
                }

                StyledText {
                    id: durationLabel
                    anchors.right: parent.right
                    font.pixelSize: Config.fontSize - 2
                    opacity: 0.5
                    text: ScreenRecorder.elapsedLabel
                }
            }

            // ─── Actions ─────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 8

                PrimaryButton {
                    width: (parent.width - openFolderBtn.width - 16) * 0.6
                    height: 40
                    text: "New recording"
                    icon: "fiber_manual_record"
                    active: true
                    onClicked: root.manualNewCapture = true
                }

                PrimaryButton {
                    width: (parent.width - openFolderBtn.width - 16) * 0.4
                    height: 40
                    text: "Play"
                    icon: "play_arrow"
                    onClicked: ScreenRecorder.playLast()
                }

                IconButton {
                    id: openFolderBtn
                    width: 40
                    height: 40
                    icon: "folder_open"
                    onClicked: ScreenRecorder.openFolder()
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.12 }

        Disclosure {
            width: parent.width
            summary: ScreenRecorder.captureAudio ? "Audio" : ""

            ToggleRow {
                width: parent.width
                icon: "mic"
                title: "Desktop audio"
                subtitle: "Records system sound alongside video"
                checked: ScreenRecorder.captureAudio
                enabled: !ScreenRecorder.recording && !ScreenRecorder.starting
                onToggled: v => ScreenRecorder.setCaptureAudio(v)
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
                                text: ScreenRecorder.lastOutputPath || ScreenRecorder.outputDir
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ScreenRecorder.openFolder()
                        }
                    }

                    PrimaryButton {
                        id: changeBtn
                        height: 34
                        text: "Change"
                        onClicked: ScreenRecorder.chooseOutputDir()
                    }
                }
            }
        }
    }
}
