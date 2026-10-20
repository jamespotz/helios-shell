import QtQuick
import Quickshell
import Quickshell.Io
import services
ShellRoot {
    id: root
    GitHubCore { id: core }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    property Timer exitDelay: Timer { interval: 50; onTriggered: terminator.running = true }
    function verify(v, message) { if (!v) throw new Error(message); }
    function compare(actual, expected, message) {
        if (actual !== expected) throw new Error(message + `: expected ${expected}, got ${actual}`);
    }
    function thread(id, updatedAt, type, url, reason) {
        return {
            id: id, reason: reason || "mention", updated_at: updatedAt,
            subject: { title: "Thread " + id, type: type || "PullRequest", url: url === undefined ? "https://api.github.com/repos/o/r/pulls/" + id : url },
            repository: { full_name: "o/r", html_url: "https://github.com/o/r" }
        };
    }
    Component.onCompleted: {
        try {
            // Web URLs come from the repository's html_url, so Enterprise hosts work too.
            compare(core.webUrl(thread("1", "t")), "https://github.com/o/r/pull/1", "pull URL");
            compare(core.webUrl(thread("2", "t", "Issue", "https://api.github.com/repos/o/r/issues/2")), "https://github.com/o/r/issues/2", "issue URL");
            compare(core.webUrl(thread("3", "t", "Commit", "https://api.github.com/repos/o/r/commits/abc")), "https://github.com/o/r/commit/abc", "commit URL");
            compare(core.webUrl(thread("4", "t", "Release", "https://api.github.com/repos/o/r/releases/99")), "https://github.com/o/r/releases", "release URL");
            compare(core.webUrl(thread("5", "t", "CheckSuite", null)), "https://github.com/o/r/actions", "CI URL");
            compare(core.webUrl(thread("6", "t", "Discussion", null)), "https://github.com/o/r/discussions", "discussion URL");
            compare(core.reasonLabel("review_requested"), "Review requested", "known reason");
            compare(core.reasonLabel("some_new_reason"), "Some new reason", "unknown reason");

            const record = core.record(thread("7", "2026-10-20T18:14:26Z", "PullRequest", undefined, "review_requested"));
            compare(record.title, "Thread 7", "record title");
            compare(record.repo, "o/r", "record repo");
            compare(record.reasonLabel, "Review requested", "record reason");
            verify(record.time instanceof Date && record.time.getTime() === Date.parse("2026-10-20T18:14:26Z"), "record time");

            // The first sync loads the inbox without cards.
            compare(core.ingest([thread("a", "1"), thread("b", "1")]).length, 0, "first sync is silent");
            compare(core.items.length, 2, "first sync fills the inbox");
            compare(core.popups.length, 0, "first sync has no popups");

            // A new thread, and new activity on a known one, both get a card.
            let fresh = core.ingest([thread("c", "1"), thread("a", "2"), thread("b", "1")]);
            compare(fresh.map(r => r.id).join(","), "c,a", "new and updated threads are fresh");
            compare(core.popups.length, 2, "fresh threads become popups");
            compare(core.ingest([thread("c", "1"), thread("a", "2"), thread("b", "1")]).length, 0, "unchanged poll is quiet");

            // Hiding a popup keeps it in the inbox; marking read removes both.
            core.hidePopup("c");
            compare(core.popups.length, 1, "hide removes popup");
            compare(core.items.length, 3, "hide keeps inbox item");
            verify(core.markRead("a"), "markRead finds item");
            compare(core.popups.length, 0, "markRead removes popup");
            compare(core.items.map(r => r.id).join(","), "c,b", "markRead removes inbox item");
            verify(!core.markRead("missing"), "markRead ignores unknown ids");

            // Read elsewhere: a thread missing from the poll leaves the inbox and its card.
            core.ingest([thread("c", "1"), thread("b", "1"), thread("d", "1")]);
            compare(core.popups.length, 1, "new thread pops");
            core.ingest([thread("c", "1"), thread("b", "1")]);
            compare(core.popups.length, 0, "thread read elsewhere drops its card");

            // DND keeps the inbox current but shows no cards.
            core.dndActive = true;
            compare(core.ingest([thread("e", "1"), thread("c", "1"), thread("b", "1")]).length, 1, "DND still reports fresh");
            compare(core.popups.length, 0, "DND suppresses cards");
            core.dndActive = false;

            core.markAllRead();
            compare(core.items.length, 0, "markAllRead empties the inbox");
            console.warn("GITHUB_TEST_PASS");
        } catch (e) { console.error("GITHUB_TEST_FAIL:", e.toString()); }
        exitDelay.start();
    }
}
