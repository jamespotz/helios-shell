import QtQuick

// The GitHub inbox as plain data: unread threads from the notifications API,
// which of them are new since the last poll, and which have an alert card.
// GitHub.qml feeds it polls and sends the matching mark-read requests.
QtObject {
    id: root
    property bool dndActive: false
    property var items: []
    property var popups: []
    // Thread id -> updated_at from the last poll; a change means new activity.
    property var _seen: ({})
    property bool _seeded: false

    readonly property var _reasonLabels: ({
        approval_requested: "Approval requested", assign: "Assigned", author: "Your thread",
        ci_activity: "CI activity", comment: "New comment", invitation: "Invitation",
        manual: "Subscribed", mention: "Mentioned", review_requested: "Review requested",
        security_alert: "Security alert", state_change: "State changed", subscribed: "Watching",
        team_mention: "Team mentioned"
    })
    readonly property var _typeIcons: ({
        PullRequest: "call_merge", Issue: "adjust", Commit: "commit", Release: "new_releases",
        Discussion: "forum", CheckSuite: "build_circle", RepositoryVulnerabilityAlert: "security"
    })

    // Takes one poll's unread threads and returns the ones that are new or
    // have new activity. The first poll only loads the inbox, so a launch
    // doesn't replay every unread thread as a card.
    function ingest(threads) {
        const records = threads.map(t => root.record(t));
        const fresh = root._seeded ? records.filter(r => root._seen[r.id] !== r.updatedAt) : [];
        const seen = {};
        for (const r of records) seen[r.id] = r.updatedAt;
        root._seen = seen;
        root._seeded = true;
        root.items = records;
        const freshIds = fresh.map(r => r.id);
        const kept = root.popups.filter(p => seen[p.id] !== undefined && !freshIds.includes(p.id));
        root.popups = (root.dndActive ? [] : fresh).concat(kept);
        return fresh;
    }

    function hidePopup(id) { root.popups = root.popups.filter(p => p.id !== id); }
    function hideAllPopups() { root.popups = []; }

    function markRead(id) {
        if (!root.items.some(r => r.id === id)) return false;
        root.items = root.items.filter(r => r.id !== id);
        root.hidePopup(id);
        return true;
    }
    function markAllRead() {
        root.items = [];
        root.popups = [];
    }

    function record(thread) {
        const subject = thread.subject || {};
        return {
            id: String(thread.id), title: subject.title || "", type: subject.type || "",
            icon: root._typeIcons[subject.type] || "notifications",
            repo: (thread.repository && thread.repository.full_name) || "",
            reason: thread.reason || "", reasonLabel: root.reasonLabel(thread.reason || ""),
            updatedAt: thread.updated_at || "", time: new Date(thread.updated_at),
            url: root.webUrl(thread)
        };
    }

    function reasonLabel(reason) {
        if (root._reasonLabels[reason]) return root._reasonLabels[reason];
        const words = reason.replace(/_/g, " ");
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    // API subject URLs (…/repos/o/r/pulls/1) mapped onto the repository's
    // web URL. Subjects without a URL, such as CI runs, open their section.
    function webUrl(thread) {
        const repoUrl = (thread.repository && thread.repository.html_url) || "";
        const subject = thread.subject || {};
        const match = /\/repos\/[^/]+\/[^/]+\/([^/]+)\/(.+)$/.exec(subject.url || "");
        if (match) {
            const kind = match[1], rest = match[2];
            if (kind === "pulls") return repoUrl + "/pull/" + rest;
            if (kind === "commits") return repoUrl + "/commit/" + rest;
            if (kind === "releases") return repoUrl + "/releases";
            return repoUrl + "/" + kind + "/" + rest;
        }
        if (subject.type === "CheckSuite") return repoUrl + "/actions";
        if (subject.type === "Discussion") return repoUrl + "/discussions";
        return repoUrl;
    }
}
