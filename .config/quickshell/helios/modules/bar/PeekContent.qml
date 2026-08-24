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
