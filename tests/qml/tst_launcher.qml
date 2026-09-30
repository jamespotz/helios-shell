import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    Component.onCompleted: {
        try {
            root.verify(Launcher._score({ title: "Firefox" }, "fire") === 3, "prefix score");
            root.verify(Launcher._score({ title: "Firefox" }, "fox") === 2, "substring score");
            const result = Launcher._normalized("window", { address: "0x1", title: "Editor", appClass: "code" }, 4);
            root.verify(result.id === "window:0x1" && result.activation.address === "0x1", "normalized window");
            const rejected = Launcher.activate({ activation: { kind: "unknown" } });
            root.verify(!rejected.accepted && !rejected.close, "failed activation remains open");
            IslandNavigation.show("test", "launcher");
            const destination = Launcher.actions.find(action => action.id === "destination:keybinds");
            const opened = Launcher.activate(Launcher._normalized("action", destination, 1));
            root.verify(opened.accepted && !opened.close, "destination action accepted without closing");
            root.verify(IslandNavigation.open && IslandNavigation.destinationId === "keybinds", "destination action opens destination");
            IslandNavigation.close();
            root.verify(Launcher.view === "list", "closing resets view");
            Launcher.setView("grid");
            const apps = Launcher.results.map(result => result.title);
            root.verify(apps.length === Launcher.applications.length, "grid lists every application");
            root.verify(apps.every((title, i) => i === 0 || apps[i - 1].localeCompare(title) <= 0), "grid is alphabetical");
            root.verify(Launcher.results.every(result => result.kind === "app"), "grid only shows apps");
            Launcher.setView("list");
            const before = Launcher._count("Dock Test App");
            Launcher.recordLaunch("Dock Test App");
            root.verify(Launcher._count("Dock Test App") === before + 1, "recordLaunch counts launches");
            Launcher.recordLaunch("");
            root.verify(!("" in Launcher.launchCounts), "empty name ignored");
            Launcher.search("/em smile");
            root.verify(Launcher.emojiMode, "emoji mode");
            console.warn("LAUNCHER_TEST_PASS");
        } catch (error) {
            console.error("LAUNCHER_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
