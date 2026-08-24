pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    // Single global NotificationServer — only one process may own the
    // org.freedesktop.Notifications DBus name, so this must stay a singleton
    // even though every screen's island reads `list` to render its own
    // notify-mode card. Newest first; NotifyCard groups when there's more
    // than one pending.
    property var list: []

    readonly property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
            // Catches expiry/close from the sender side too, not just our own
            // dismiss() — otherwise a notification closed elsewhere would
            // linger in the list forever.
            notification.closed.connect(() => root.remove(notification));
            root.list = [notification].concat(root.list);
        }
    }

    function remove(notification) {
        root.list = root.list.filter(n => n !== notification);
    }

    function dismiss(notification) {
        notification.dismiss();
    }

    function dismissAll() {
        for (const n of root.list) n.dismiss();
    }
}
