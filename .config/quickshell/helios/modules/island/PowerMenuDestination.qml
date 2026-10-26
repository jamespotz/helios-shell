import QtQuick
import Quickshell
import "../../services"
import "../../components"

Item {
    id: root

    property string pendingAction: ""

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    focus: true
    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_1: lockAction.activate(); break;
        case Qt.Key_2: logoutAction.activate(); break;
        case Qt.Key_3: suspendAction.activate(); break;
        case Qt.Key_4: restartAction.activate(); break;
        case Qt.Key_5: poweroffAction.activate(); break;
        default: return;
        }
        event.accepted = true;
    }

    // Bar establishes its Hyprland keyboard grab shortly after loading;
    // grabbing focus before that settles gets clobbered (see
    // LauncherDestination's identical focusSearchTimer).
    Timer {
        interval: 120
        running: true
        onTriggered: root.forceActiveFocus()
    }

    Column {
        id: col
        spacing: 14

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "power_settings_new"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Power"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        Row {
            id: row
            spacing: 18

            PowerAction {
                id: lockAction
                icon: "lock"
                label: "Lock"
                keyHint: "1"
                onActivated: { ShellState.lock(); IslandNavigation.close(); }
            }
            PowerAction {
                id: logoutAction
                icon: "logout"
                label: "Logout"
                keyHint: "2"
                destructive: true
                armed: root.pendingAction === label
                onArmRequested: root.pendingAction = label
                onActivated: { Session.logout(); IslandNavigation.close(); }
            }
            PowerAction {
                id: suspendAction
                icon: "dark_mode"
                label: "Suspend"
                keyHint: "3"
                onActivated: { Session.suspend(); IslandNavigation.close(); }
            }
            PowerAction {
                id: restartAction
                icon: "restart_alt"
                label: "Reboot"
                keyHint: "4"
                destructive: true
                armed: root.pendingAction === label
                onArmRequested: root.pendingAction = label
                onActivated: { Session.reboot(); IslandNavigation.close(); }
            }
            PowerAction {
                id: poweroffAction
                icon: "power_settings_new"
                label: "Shutdown"
                keyHint: "5"
                destructive: true
                armed: root.pendingAction === label
                onArmRequested: root.pendingAction = label
                onActivated: { Session.poweroff(); IslandNavigation.close(); }
            }
        }
    }
}
