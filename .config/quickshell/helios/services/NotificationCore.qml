import QtQuick

QtObject {
    id: root
    required property var applicationAdapter
    property bool dndActive: false
    property var _popups: []
    property var _history: []
    property var _liveById: ({})
    property int _nextId: 1
    readonly property int historyMax: 50
    readonly property var state: ({ popups: root._popups, history: root._history, dndActive: root.dndActive })

    function accept(notification) {
        const id = "notification-" + root._nextId++;
        root._liveById[id] = notification;
        notification.closed.connect(() => root._remove(id));
        root._history = [root._record(id, notification, false)].concat(root._history).slice(0, root.historyMax);
        if (!root.dndActive) root._popups = [root._record(id, notification, true)].concat(root._popups);
        return id;
    }

    function dismiss(id) {
        const notification = root._liveById[id];
        if (!notification) return false;
        notification.dismiss();
        return true;
    }
    function dismissAll() { for (const record of root._popups.slice()) root.dismiss(record.id); }
    function clearHistory() { root._history = []; }

    function open(id) {
        const notification = root._liveById[id];
        if (!notification) {
            const entry = root._history.find(n => n.id === id);
            return entry ? root.applicationAdapter.focusOrLaunch(entry.desktopEntry, entry.appName) : false;
        }
        const action = root._findDefaultAction(notification);
        const desktopEntry = notification.desktopEntry || "";
        const appName = notification.appName || "";
        if (action) {
            action.invoke();
            if (desktopEntry || appName) {
                root.applicationAdapter.focusWindow(desktopEntry, appName);
                root.applicationAdapter.focusWithRetry(desktopEntry, appName, 3);
            }
            return true;
        }
        return root.applicationAdapter.focusWindow(desktopEntry, appName);
    }

    function _remove(id) {
        root._popups = root._popups.filter(n => n.id !== id);
        delete root._liveById[id];
    }
    function _record(id, notification, live) {
        return {
            id: id, summary: notification.summary || "", body: notification.body || "",
            appName: notification.appName || "", appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "", time: new Date(),
            canOpen: !!notification.desktopEntry || (!!live && !!root._findDefaultAction(notification))
        };
    }
    function _findDefaultAction(notification) {
        if (!notification || !notification.actions) return null;
        return notification.actions.find(a => a.identifier === "default")
            || notification.actions.find(a => a.identifier === "") || null;
    }
}
