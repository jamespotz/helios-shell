import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Auto-peek card for an imminent calendar event — Calendar.qml's
// alertTimer surfaces one event 5 minutes before it starts (see
// upcomingAlert there); this just renders it, the same relationship
// NotifyCard.qml has to Notifications' popup list.
Item {
    id: root

    readonly property var event: Calendar.upcomingAlert
    readonly property string joinUrl: root.event && root.event.links && root.event.links.length > 0 ? root.event.links[0] : ""

    implicitWidth: Config.notifyWidth
    implicitHeight: rowLayout.implicitHeight

    HoverHandler { id: hoverTracker }

    // Countdown text needs its own tick — the event's start time doesn't
    // change, "now" does.
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root._nowTick = Date.now() }
    property double _nowTick: Date.now()

    readonly property int minutesUntil: {
        if (!root.event || !root.event.startTime) return 0;
        const [y, m, d] = root.event.date.split("-").map(Number);
        const [hh, mm] = root.event.startTime.split(":").map(Number);
        const start = new Date(y, m - 1, d, hh, mm).getTime();
        return Math.round((start - root._nowTick) / 60000);
    }

    // Auto-dismiss after a pause, same idea as NotifyCard's single-
    // notification timer — hovering pauses it so a glance doesn't get cut off.
    Timer {
        id: autoDismissTimer
        interval: 12000
        running: root.event !== null
        onTriggered: {
            if (hoverTracker.hovered) { autoDismissTimer.restart(); return; }
            Calendar.dismissAlert();
        }
    }

    Row {
        id: rowLayout
        width: parent.width
        spacing: 12

        MaterialIcon {
            icon: root.joinUrl ? "videocam" : "event"
            font.pixelSize: 20
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - 20 - 12 - actionRow.width - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                font.weight: Font.DemiBold
                text: root.event ? root.event.summary : ""
            }
            StyledText {
                width: parent.width
                elide: Text.ElideRight
                color: Colors.subtext
                font.pixelSize: Config.fontSize - 2
                text: root.minutesUntil > 0 ? ("Starts in " + root.minutesUntil + " min") : "Starting now"
            }
        }

        Row {
            id: actionRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            IconButton {
                visible: !!root.joinUrl
                icon: "videocam"
                iconSize: 14
                onClicked: Quickshell.execDetached(["xdg-open", root.joinUrl])
            }

            IconButton {
                icon: "close"
                iconSize: 14
                onClicked: Calendar.dismissAlert()
            }
        }
    }
}
