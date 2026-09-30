pragma Singleton
import QtQuick
import Quickshell.Io

// Plays a freedesktop sound when an alert card appears — new notification
// (not low urgency), meeting reminder, low device battery. Off unless
// Settings > Island > Alerts > Alert sounds is on. Referenced once from
// shell.qml so it exists from startup.
QtObject {
    id: root

    readonly property var soundFor: ({ notify: "message-new-instant", meeting: "bell", battery: "dialog-warning" })

    function play(kind) {
        if (!Config.alertSounds || !root.soundFor[kind]) return;
        root._player.command = ["canberra-gtk-play", "--id=" + root.soundFor[kind]];
        root._player.running = true;
    }

    property Process _player: Process {}

    property Connections _notifications: Connections {
        target: Notifications
        function onPopupAdded(record) { if (record.urgency !== 0) root.play("notify"); }
    }
    property Connections _calendar: Connections {
        target: Calendar
        function onUpcomingAlertChanged() { if (Calendar.upcomingAlert && Config.showMeetingAlerts) root.play("meeting"); }
    }
    property Connections _bluetooth: Connections {
        target: Bluetooth
        function onLowBatteryAlertChanged() { if (Bluetooth.lowBatteryAlert && Config.showBatteryAlerts) root.play("battery"); }
    }
}
