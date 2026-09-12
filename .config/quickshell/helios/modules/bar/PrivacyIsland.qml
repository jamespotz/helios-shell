import QtQuick
import "../../services"
import "../../components"

// Privacy dashboard — one place to see what's currently listening: which
// app (if any) holds the microphone or camera open (via MicActivity /
// CameraActivity's PipeWire stream tracking), whether Helios' own screen
// recorder is running, and a glance at recent clipboard activity.
Item {
    id: root

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 8

    function appList(apps) {
        return apps.length > 0 ? apps.join(", ") : "";
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 14

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "privacy_tip"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Privacy"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        // ─── Microphone ────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "mic"
                font.pixelSize: 20
                color: MicActivity.isSystemMicActive ? Colors.danger : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 20 - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Microphone"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 1 }
                StyledText {
                    text: MicActivity.isSystemMicActive ? ("In use by " + root.appList(MicActivity.activeApps)) : "Not in use"
                    font.pixelSize: Config.fontSize - 2
                    color: MicActivity.isSystemMicActive ? Colors.danger : Colors.subtext
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
        }

        // ─── Camera ────────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "videocam"
                font.pixelSize: 20
                color: CameraActivity.isSystemCameraActive ? Colors.danger : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 20 - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Camera"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 1 }
                StyledText {
                    text: CameraActivity.isSystemCameraActive ? ("In use by " + root.appList(CameraActivity.activeApps)) : "Not in use"
                    font.pixelSize: Config.fontSize - 2
                    color: CameraActivity.isSystemCameraActive ? Colors.danger : Colors.subtext
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
        }

        // Separator
        Rectangle { width: parent.width; height: 0.5; color: Colors.overlay; opacity: 0.3 }

        // ─── Screen recording ──────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "screen_share"
                font.pixelSize: 20
                color: ScreenRecorder.recording ? Colors.danger : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 20 - 10 - stopBtn.width - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Screen Recording"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 1 }
                StyledText {
                    text: ScreenRecorder.recording ? "Recording this screen" : "Not recording"
                    font.pixelSize: Config.fontSize - 2
                    color: ScreenRecorder.recording ? Colors.danger : Colors.subtext
                }
            }

            IconButton {
                id: stopBtn
                visible: ScreenRecorder.recording
                anchors.verticalCenter: parent.verticalCenter
                icon: "stop_circle"
                iconColor: Colors.danger
                onClicked: ScreenRecorder.stop()
            }
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Third-party screen shares (video calls, remote desktop) aren't tracked here — only Helios' own recorder."
            font.pixelSize: Config.fontSize - 3
            color: Colors.subtext
            opacity: 0.7
        }

        // Separator
        Rectangle { width: parent.width; height: 0.5; color: Colors.overlay; opacity: 0.3 }

        // ─── Clipboard ─────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "content_paste"
                font.pixelSize: 20
                color: Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 20 - 10 - clipBtn.width - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Clipboard"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 1 }
                StyledText {
                    text: Clipboard.items.length + " item" + (Clipboard.items.length === 1 ? "" : "s") + " in history"
                    font.pixelSize: Config.fontSize - 2
                    color: Colors.subtext
                }
            }

            IconButton {
                id: clipBtn
                anchors.verticalCenter: parent.verticalCenter
                icon: "open_in_new"
                onClicked: {
                    // select() only swaps the island's current tab — it never
                    // opens the island, so from here (often reached from the
                    // Settings window, where the island isn't open at all)
                    // clicking did nothing visible. show() actually opens it.
                    // Closing Settings first also avoids it sitting on the
                    // same Overlay layer on top of the island.
                    const screenName = IslandNavigation.open ? IslandNavigation.screen : Bridge.settingsScreen;
                    Bridge.closeSettings();
                    IslandNavigation.show(screenName, "clipboard");
                }
            }
        }
    }

    Component.onCompleted: Clipboard.refresh()
}
