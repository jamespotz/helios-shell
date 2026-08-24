import QtQuick
import "../../services"

// What the island expands to on hover: the same workspaces/clock/tray/status
// content the old always-visible bar used to show permanently.
Item {
    id: root

    required property var targetScreen

    implicitWidth: row.implicitWidth
    implicitHeight: Config.peekHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Rectangle {
            visible: ScreenRecorder.recording
            width: 8
            height: 8
            radius: 4
            color: Colors.danger
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
                running: ScreenRecorder.recording
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.25; duration: 600 }
                NumberAnimation { from: 0.25; to: 1; duration: 600 }
            }
        }

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

        Clock { visible: Config.showClock; targetScreen: root.targetScreen; anchors.verticalCenter: parent.verticalCenter }

        WeatherWidget {
            visible: Config.showWeather && Weather.available
            targetScreen: root.targetScreen
            anchors.verticalCenter: parent.verticalCenter
        }

        Tray { visible: Config.showTray; anchors.verticalCenter: parent.verticalCenter }

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
