import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../services"
import "../../components"

Item {
    id: root

    property bool mediaPlaying: false
    property var targetScreen: null

    readonly property var player: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.find(p => p.isPlaying) || null;
    }

    // Content-driven so the bump doesn't clip or look lopsided once weather
    // joins the clock — Config.idleBumpWidth is just the floor for when
    // there's nothing extra to show yet (e.g. weather hasn't loaded).
    implicitWidth: Math.max(Config.idleBumpWidth, row.implicitWidth + 24)
    implicitHeight: Config.idleBumpHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Workspaces {
            visible: Config.showIdleWorkspaces
            targetScreen: root.targetScreen
            anchors.verticalCenter: parent.verticalCenter
        }

        ActiveWindow {
            visible: Config.showIdleActiveWindow
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 120)
        }

        Rectangle {
            visible: root.mediaPlaying && Config.showIdleMedia
            width: 16
            height: 16
            radius: 4
            color: Colors.surfaceHigh
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                visible: !!(root.player && root.player.trackArtUrl)
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !(root.player && root.player.trackArtUrl)
                icon: "music_note"
                font.pixelSize: 10
            }
        }

        MiniVisualizer {
            visible: root.mediaPlaying && Config.showIdleMedia
            active: root.mediaPlaying && Config.showIdleMedia
            levels: Cava.bars.map(v => v / Cava.maxRange)
            barColor: Colors.text
            maxHeight: 10
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: Config.showIdleClock
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Config.fontSize - 2
            text: Qt.formatDateTime(clock.date, "h:mm AP")
        }

        MaterialIcon {
            visible: Weather.available && Config.showIdleWeather
            icon: Weather.icon
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: Weather.available && Config.showIdleWeather
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Config.fontSize - 2
            text: Math.round(Weather.tempC) + "°"
        }

        Tray { visible: Config.showIdleTray; anchors.verticalCenter: parent.verticalCenter }

        ClipboardWidget {
            visible: Config.showIdleClipboard
            targetScreen: root.targetScreen
            anchors.verticalCenter: parent.verticalCenter
        }

        StatusIndicators {
            visible: Config.showIdleStatusIndicators
            targetScreen: root.targetScreen
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
