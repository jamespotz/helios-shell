pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    readonly property NotificationCore _core: NotificationCore {
        applicationAdapter: AppLaunch
        dndActive: Bridge.dndEnabled
    }
    readonly property var state: root._core.state

    readonly property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notification => {
            notification.tracked = true;
            root._core.accept(notification);
        }
    }

    function open(id) { return root._core.open(id); }
    function dismiss(id) { return root._core.dismiss(id); }
    function dismissAll() { root._core.dismissAll(); }
    function clearHistory() { root._core.clearHistory(); }
}
