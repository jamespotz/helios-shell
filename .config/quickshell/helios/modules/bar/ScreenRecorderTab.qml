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

    implicitWidth: 280
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        Row {
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: root.modes

                delegate: Rectangle {
                    id: modeBtn
                    required property var modelData
                    readonly property bool isActive: ScreenRecorder.mode === modelData.key

                    width: modeContent.implicitWidth + 16
                    height: 26
                    radius: height / 2
                    color: isActive ? Colors.accent : Colors.surfaceHigh
                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: modeHover.hovered && !modeBtn.isActive ? 0.25 : 0
                    }

                    HoverHandler { id: modeHover }

                    Row {
                        id: modeContent
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            icon: modeBtn.modelData.icon
                            font.pixelSize: 13
                            color: modeBtn.isActive ? Colors.accentText : Colors.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: modeBtn.modelData.label
                            font.pixelSize: Config.fontSize - 3
                            color: modeBtn.isActive ? Colors.accentText : Colors.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !ScreenRecorder.recording && !ScreenRecorder.starting
                        onClicked: ScreenRecorder.setMode(modeBtn.modelData.key)
                    }
                }
            }
        }

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
                    const screen = Bridge.islandScreen;
                    const startingNew = !ScreenRecorder.recording;
                    if (startingNew) Bridge.closeIsland();
                    ScreenRecorder.toggle(screen);
                }
            }
        }

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            MaterialIcon { icon: "mic"; font.pixelSize: 14; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Desktop audio"; font.pixelSize: Config.fontSize - 2; anchors.verticalCenter: parent.verticalCenter }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: ScreenRecorder.captureAudio
                enabled: !ScreenRecorder.recording && !ScreenRecorder.starting
                onToggled: v => ScreenRecorder.captureAudio = v
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.15 }

        Row {
            width: parent.width
            spacing: 8

            MaterialIcon { icon: "folder_open"; font.pixelSize: 14; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }

            StyledText {
                id: folderText
                width: parent.width - 24
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                opacity: folderHover.hovered ? 1 : 0.7
                font.pixelSize: Config.fontSize - 2
                font.underline: folderHover.hovered
                text: ScreenRecorder.lastOutputPath || ScreenRecorder.outputDir

                MouseArea {
                    id: folderHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ScreenRecorder.openFolder()
                }
            }
        }
    }
}
