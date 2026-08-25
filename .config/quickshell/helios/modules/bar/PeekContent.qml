import QtQuick
import "../../services"
import "../../components"

// Hover-expanded state — Apple menu bar philosophy: two clearly separated
// zones (left: navigation/context, right: utilities/status) with generous
// internal spacing and thin separators for visual grouping. Each zone
// self-hides when all its children are toggled off.
Item {
    id: root

    required property var targetScreen

    readonly property bool hasLeftCluster: ScreenRecorder.recording || Config.showWorkspaces || Config.showActiveWindow
    readonly property bool hasRightCluster: Config.showClock || (Config.showWeather && Weather.available)
        || Config.showTray || Config.showClipboard || Config.showStatusIndicators

    implicitWidth: row.implicitWidth
    implicitHeight: Config.peekHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // --- Left cluster: workspace context ---
        Row {
            id: leftCluster
            visible: root.hasLeftCluster
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            RecordingDot { anchors.verticalCenter: parent.verticalCenter }

            Workspaces {
                visible: Config.showWorkspaces
                targetScreen: root.targetScreen
                anchors.verticalCenter: parent.verticalCenter
            }

            ActiveWindow {
                visible: Config.showActiveWindow
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
            }
        }

        // --- Separator between clusters ---
        Item {
            visible: root.hasLeftCluster && root.hasRightCluster
            width: 32
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: 14
                radius: 0.5
                color: Colors.overlay
                opacity: 0.3
            }
        }

        // --- Right cluster: utilities & status ---
        Row {
            id: rightCluster
            visible: root.hasRightCluster
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Clock {
                visible: Config.showClock
                targetScreen: root.targetScreen
                anchors.verticalCenter: parent.verticalCenter
            }

            WeatherWidget {
                visible: Config.showWeather && Weather.available
                targetScreen: root.targetScreen
                anchors.verticalCenter: parent.verticalCenter
            }

            // Thin separator before system tray/indicators
            Rectangle {
                visible: (Config.showClock || (Config.showWeather && Weather.available))
                    && (Config.showTray || Config.showClipboard || Config.showStatusIndicators)
                width: 1
                height: 14
                radius: 0.5
                color: Colors.overlay
                opacity: 0.3
                anchors.verticalCenter: parent.verticalCenter
            }

            Tray {
                visible: Config.showTray
                anchors.verticalCenter: parent.verticalCenter
            }

            ClipboardWidget {
                visible: Config.showClipboard
                targetScreen: root.targetScreen
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusIndicators {
                visible: Config.showStatusIndicators
                targetScreen: root.targetScreen
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
