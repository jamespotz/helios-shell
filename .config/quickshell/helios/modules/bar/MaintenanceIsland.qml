import QtQuick
import "../../services"
import "../../components"

// System maintenance — pending dnf/flatpak updates, reboot-required
// status, pending firmware updates, and failed systemd units. Read-only
// status + a manual refresh; actually applying updates needs a privileged
// prompt this shell doesn't own, so that stays a terminal/GNOME Software job.
Item {
    id: root

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 8

    function timeAgo(ms) {
        if (!ms) return "";
        const mins = Math.max(0, Math.round((Date.now() - ms) / 60000));
        if (mins < 1) return "just now";
        if (mins < 60) return mins + "m ago";
        return Math.round(mins / 60) + "h ago";
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 14

        Row {
            width: parent.width
            spacing: 8
            MaterialIcon { icon: "handyman"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText {
                text: "Maintenance"
                font.weight: Font.DemiBold
                font.pixelSize: Config.fontSize + 2
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - parent.children[0].width - parent.children[1].width - 16 - refreshBtn.width; height: 1 }
            IconButton {
                id: refreshBtn
                icon: "refresh"
                enabled: !Maintenance.checking
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Maintenance.refresh()
            }
        }

        Row {
            width: parent.width
            spacing: 10
            MaterialIcon {
                icon: "download"
                font.pixelSize: 20
                color: Maintenance.updateCount > 0 ? Colors.accent : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                width: parent.width - 30
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Package updates"; font.weight: Font.DemiBold }
                StyledText {
                    text: Maintenance.dnfUpdates === null && Maintenance.flatpakUpdates === null
                        ? "Unavailable"
                        : (Maintenance.dnfUpdates || 0) + " dnf  ·  " + (Maintenance.flatpakUpdates || 0) + " Flatpak"
                    font.pixelSize: Config.fontSize - 2
                    color: Colors.subtext
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10
            visible: !!Maintenance.rebootRequired
            MaterialIcon { icon: "restart_alt"; font.pixelSize: 20; color: Colors.warning; anchors.verticalCenter: parent.verticalCenter }
            Column {
                width: parent.width - 30
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Reboot required"; font.weight: Font.DemiBold; color: Colors.warning }
                StyledText { text: "Core libraries changed since boot"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            visible: Maintenance.firmwareUpdates.length > 0

            StyledText { text: "Firmware"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize - 1; color: Colors.subtext }
            Repeater {
                model: Maintenance.firmwareUpdates
                Row {
                    width: col.width
                    spacing: 10
                    MaterialIcon { icon: "memory"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText {
                        text: modelData.name + " → " + modelData.version
                        font.pixelSize: Config.fontSize - 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            visible: Maintenance.failedUnits.length > 0

            StyledText { text: "Failed services"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize - 1; color: Colors.danger }
            Repeater {
                model: Maintenance.failedUnits
                Row {
                    width: col.width
                    spacing: 10
                    MaterialIcon { icon: "error"; font.pixelSize: 18; color: Colors.danger; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: modelData; font.pixelSize: Config.fontSize - 2; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        StyledText {
            text: Maintenance.checking
                ? "Checking…"
                : (Maintenance.lastCheckedAt ? "Checked " + root.timeAgo(Maintenance.lastCheckedAt) : "")
            font.pixelSize: Config.fontSize - 3
            color: Colors.subtext
        }
    }
}
