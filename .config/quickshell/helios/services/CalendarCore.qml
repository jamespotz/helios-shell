import QtQuick

QtObject {
    id: root

    property var events: []
    property var subscriptions: []
    property var subscriptionErrors: []
    property bool ready: false
    property bool refreshing: false

    signal persistenceRequested(var subscriptions)
    signal refreshRequested()

    readonly property var state: ({
        ready: root.ready,
        refreshing: root.refreshing,
        events: root.events,
        eventsByDate: root._eventsByDate(root.events),
        subscriptions: root.subscriptions.map(s => ({
            id: s.id,
            label: s.label,
            url: s.url,
            error: root.subscriptionErrors.find(e => e.id === s.id) || null
        }))
    })

    function subscribe(label, url) {
        const cleanLabel = String(label || "").trim();
        const cleanUrl = String(url || "").trim();
        if (!cleanLabel || !cleanUrl) return false;
        const taken = new Set(root.subscriptions.map(s => s.id));
        let id;
        do id = "sub-" + Math.random().toString(36).slice(2, 10); while (taken.has(id));
        root.subscriptions = root.subscriptions.concat([{ id: id, label: cleanLabel, url: cleanUrl }]);
        root.persistenceRequested(root.subscriptions);
        root.refreshRequested();
        return true;
    }

    function unsubscribe(id) {
        if (!root.subscriptions.some(s => s.id === id)) return false;
        root.subscriptions = root.subscriptions.filter(s => s.id !== id);
        root.persistenceRequested(root.subscriptions);
        root.refreshRequested();
        return true;
    }

    function beginRefresh() { root.refreshing = true; }

    function completeRefresh(result) {
        const next = result || {};
        root.events = next.events || [];
        root.subscriptionErrors = next.subscriptionErrors || [];
        root.ready = true;
        root.refreshing = false;
    }

    function _eventsByDate(list) {
        const grouped = {};
        for (const event of (list || [])) {
            if (!grouped[event.date]) grouped[event.date] = [];
            grouped[event.date].push(event);
        }
        return grouped;
    }
}
