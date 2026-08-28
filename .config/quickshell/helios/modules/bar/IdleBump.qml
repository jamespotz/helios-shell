import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import QtQuick.Effects
import "../../services"
import "../../components"

// The collapsed idle pill — Apple Dynamic Island style: minimal, clean,
// with generous internal spacing and refined typography. Shows only
// essential glanceable info: time, weather, and now-playing art.
Item {
    id: root

    property bool mediaPlaying: false
    property var targetScreen: null

    readonly property var player: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.find(p => p.isPlaying) || null;
    }

    // Content-driven width with a comfortable floor — Apple's idle pill
    // never looks cramped; generous horizontal padding (28px total).
    implicitWidth: Math.max(Config.idleBumpWidth, row.implicitWidth + 28)
    implicitHeight: Config.idleBumpHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        // Recording indicator — safety-critical, always visible regardless
        // of widget toggles.
        RecordingDot { anchors.verticalCenter: parent.verticalCenter }

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

        // Now-playing: album art thumbnail in a circle
        Item {
            visible: root.mediaPlaying && Config.showIdleMedia
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Colors.surfaceHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !(root.player && root.player.trackArtUrl)
                    icon: "music_note"
                    font.pixelSize: 11
                    color: Colors.subtext
                }
            }

            Rectangle {
                id: idleArtMask
                anchors.fill: parent
                radius: width / 2
                visible: false
            }

            Image {
                id: idleArtImg
                anchors.fill: parent
                visible: false
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MultiEffect {
                anchors.fill: idleArtMask
                source: idleArtImg
                maskEnabled: true
                maskSource: idleArtMask
                visible: !!(root.player && root.player.trackArtUrl)
            }
        }

        // Audio visualizer — kept compact, Apple-style minimal bars
        MiniVisualizer {
            visible: root.mediaPlaying && Config.showIdleMedia
            active: root.mediaPlaying && Config.showIdleMedia
            levels: active ? Cava.bars.map(v => v / Cava.maxRange) : []
            barColor: Colors.accent
            maxHeight: 12
            anchors.verticalCenter: parent.verticalCenter
        }

        // Time — clean, medium weight, slightly larger than before for
        // the idle state to be readable at a glance.
        StyledText {
            visible: Config.showIdleClock
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Config.fontSize
            font.weight: Font.Medium
            text: Qt.formatDateTime(clock.date, Config.timeFormat)
            opacity: 0.95
        }

        // Thin separator between time and weather — Apple uses these
        // sparingly for visual grouping without adding a gap.
        Rectangle {
            visible: Config.showIdleClock && Weather.available && Config.showIdleWeather
            width: 1
            height: 12
            radius: 0.5
            color: Colors.overlay
            opacity: 0.4
            anchors.verticalCenter: parent.verticalCenter
        }

        // Weather: icon + temp, compact
        MaterialIcon {
            visible: Weather.available && Config.showIdleWeather
            icon: Weather.icon
            color: Colors.accent
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: Weather.available && Config.showIdleWeather
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Config.fontSize - 1
            font.weight: Font.Medium
            text: Math.round(Weather.tempC) + "°"
            opacity: 0.85
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
