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

    // A notification that got a card (not suppressed by DND).
    signal popupAdded(var record)

    function accept(notification) {
        const id = "notification-" + root._nextId++;
        root._liveById[id] = notification;
        notification.closed.connect(() => root._remove(id));
        root._history = [root._record(id, notification, false)].concat(root._history).slice(0, root.historyMax);
        if (!root.dndActive) {
            const record = root._record(id, notification, true);
            root._popups = [record].concat(root._popups);
            root.popupAdded(record);
        }
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

    // When the popup timer should fire and which popups it dismisses.
    // Urgency: 0 low, 1 normal, 2 critical. Low-only stacks leave sooner;
    // critical ones stay until dismissed when keepCritical is set, and
    // interval 0 means no timer.
    function expiry(popups, baseMs, keepCritical) {
        const expiring = keepCritical ? popups.filter(p => p.urgency !== 2) : popups;
        if (expiring.length === 0) return { interval: 0, dismissIds: [] };
        const allLow = expiring.every(p => p.urgency === 0);
        return { interval: allLow ? Math.round(baseMs / 2) : baseMs, dismissIds: expiring.map(p => p.id) };
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
            urgency: notification.urgency === undefined ? 1 : notification.urgency,
            canOpen: !!notification.desktopEntry || (!!live && !!root._findDefaultAction(notification))
        };
    }
    function _findDefaultAction(notification) {
        if (!notification || !notification.actions) return null;
        return notification.actions.find(a => a.identifier === "default")
            || notification.actions.find(a => a.identifier === "") || null;
    }
}
