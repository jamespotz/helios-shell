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
            const firefox = { id: "firefox", name: "Firefox", icon: "firefox" };
            const files = { id: "org.gnome.Nautilus", name: "Files", icon: "nautilus" };
            const entries = { "firefox": firefox, "org.gnome.Nautilus": files };
            const resolve = cls => cls === "firefox" ? firefox : null;
            const windows = [
                { address: "0x1", cls: "firefox", workspaceId: 1, x: 0, y: 0, width: 800, height: 600 },
                { address: "0x2", cls: "firefox", workspaceId: 2, x: 0, y: 0, width: 800, height: 600 },
                { address: "0x3", cls: "mystery", workspaceId: 1, x: 900, y: 0, width: 100, height: 100 }
            ];

            const items = Dock._items(["org.gnome.Nautilus", "firefox", "gone"], windows, key => entries[key] || null, resolve);
            root.verify(items.map(item => item.key).join(",") === "org.gnome.Nautilus,firefox,class:mystery", "pins first, then running, missing pins dropped");
            root.verify(items[1].pinned && items[1].windows.length === 2, "running pinned app groups its windows");
            root.verify(!items[2].pinned && items[2].entry === null && items[2].name === "mystery", "unresolved class keeps its own item");
            root.verify(items[0].windows.length === 0, "pinned app not running has no windows");

            root.verify(Dock._overlaps(windows, 1, Qt.rect(100, 500, 200, 60)), "window on active workspace overlaps");
            root.verify(!Dock._overlaps(windows, 1, Qt.rect(100, 700, 200, 60)), "window above the dock does not overlap");
            root.verify(!Dock._overlaps(windows, 3, Qt.rect(100, 500, 200, 60)), "other workspaces ignored");

            Dock.placeAt("a", 0);
            Dock.placeAt("b", 5);
            Dock.placeAt("c", 1);
            root.verify(Dock.pins.join(",") === "a,c,b", "placeAt inserts and clamps");
            Dock.placeAt("b", 0);
            root.verify(Dock.pins.join(",") === "b,a,c", "placeAt moves existing pin");
            Dock.pin("a");
            root.verify(Dock.pins.length === 3, "pin is idempotent");
            Dock.unpin("a");
            root.verify(Dock.pins.join(",") === "b,c" && !Dock.isPinned("a"), "unpin");
            root.verify(Dock.keyOf({ name: "Extra" }) === "Extra", "key falls back to name");

            const history = [
                { desktopEntry: "firefox", appName: "Firefox", time: new Date(2000) },
                { desktopEntry: "", appName: "mystery", time: new Date(3000) },
                { desktopEntry: "", appName: "Other", time: new Date(4000) }
            ];
            const badges = Dock._badges(items, history, {});
            root.verify(badges["firefox"] === 1 && badges["class:mystery"] === 1 && !badges["org.gnome.Nautilus"], "badges match entry id and window class");
            root.verify(!Dock._badges(items, history, { "firefox": 2500 })["firefox"], "badges clear after seen");

            Dock.setOption("iconSize", 200);
            root.verify(Dock.iconSize === Dock.range("iconSize")[1], "icon size clamps");
            Dock.setOption("iconSpacing", -3);
            root.verify(Dock.iconSpacing === 0, "icon spacing clamps");
            Dock.setOption("magnifyScale", 1.63);
            root.verify(Math.abs(Dock.magnifyScale - 1.65) < 1e-9, "magnification snaps to step");
            Dock.setOption("iconSize", "big");
            root.verify(Dock.iconSize === Dock.range("iconSize")[1], "wrong type ignored");
            Dock.setOption("autohide", "bogus");
            root.verify(Dock.autohide === "intellihide", "unknown autohide ignored");
            Dock.setOption("autohide", "never");
            root.verify(Dock.autohide === "never", "autohide set");
            Dock.resetOptions();
            root.verify(Dock.autohide === "intellihide" && Dock.iconSize === 44 && Dock.magnifyScale === 1.45, "reset restores defaults");
            root.verify(Dock.pins.join(",") === "b,c", "reset keeps pins");
            Dock.movePin("c", -1);
            root.verify(Dock.pins.join(",") === "c,b", "movePin up");
            Dock.movePin("c", -1);
            root.verify(Dock.pins.join(",") === "c,b", "movePin clamps at top");
            const pinnedOnly = Dock._items(["firefox"], windows, key => entries[key] || null, resolve, false);
            root.verify(pinnedOnly.length === 1 && pinnedOnly[0].windows.length === 2, "showRunning off keeps only pins");
            const withSeparator = Dock._items(["firefox", "separator:1", "org.gnome.Nautilus"], windows, key => entries[key] || null, resolve, false);
            root.verify(withSeparator.map(item => item.key).join(",") === "firefox,separator:1,org.gnome.Nautilus", "separator keeps its pin position");
            root.verify(withSeparator[1].separator && withSeparator[1].pinned && withSeparator[1].windows.length === 0, "separator item is pinned, windowless");
            root.verify(!Dock._badges(withSeparator, [{ desktopEntry: "", appName: "", time: new Date(5000) }], {})["separator:1"], "separators never get badges");
            const savedPins = Dock.pins;
            Dock.pins = ["a", "b"];
            Dock.addSeparator(1);
            Dock.addSeparator();
            root.verify(Dock.pins.join(",") === "a,separator:1,b,separator:2", "addSeparator inserts unique separators");
            Dock.movePin("separator:2", -2);
            root.verify(Dock.pins.join(",") === "a,separator:2,separator:1,b", "separators reorder like pins");
            Dock.unpin("separator:1");
            root.verify(Dock.pins.join(",") === "a,separator:2,b" && Dock.isSeparator("separator:2") && !Dock.isSeparator("a"), "separator removed");
            Dock.pins = savedPins;
            const withRecents =Dock._items(["firefox"], windows, key => entries[key] || null, resolve, true,
                ["firefox", "gone", "org.gnome.Nautilus", "class:mystery"], 3);
            root.verify(withRecents.map(item => item.key).join(",") === "firefox,class:mystery,org.gnome.Nautilus", "recents skip pinned, running and unknown apps");
            root.verify(withRecents[2].recent && withRecents[2].windows.length === 0, "recent item has no windows");
            const oneRecent = Dock._items([], [], key => entries[key] || null, resolve, true, ["firefox", "org.gnome.Nautilus"], 1);
            root.verify(oneRecent.map(item => item.key).join(",") === "firefox", "recent count limits the section");
            root.verify(Dock._scope([{ key: "r", pinned: false, recent: true, windows: [] }], "workspace", "DP-1", 1).length === 1, "scope keeps recent apps");
            const savedRecents = Dock.recents;
            Dock.recents = [];
            Dock.noteRecent("a");
            Dock.noteRecent("b");
            Dock.noteRecent("a");
            Dock.noteRecent("class:mystery");
            root.verify(Dock.recents.join(",") === "a,b", "noteRecent moves to front, ignores class-only keys");
            Dock.recents = savedRecents;
            Dock.setOption("glass", "sometimes");
            root.verify(Dock.glass === "follow", "unknown glass mode ignored");
            Dock.setOption("glass", "off");
            root.verify(Dock.glass === "off" && !Dock.glassActive, "glass forced off");
            Dock.setOption("glass", "on");
            root.verify(Dock.glassActive, "glass forced on");
            Dock.setOption("recentCount", 50);
            root.verify(Dock.recentCount === Dock.range("recentCount")[1], "recent count clamps");
            Dock.resetOptions();
            Dock.setShownOn("DP-1", false);
            root.verify(!Dock.shownOn("DP-1") && Dock.shownOn("HDMI-A-1"), "per-screen visibility");
            Dock.setShownOn("DP-1", true);
            root.verify(Dock.shownOn("DP-1") && Dock.hiddenScreens.length === 0, "screen re-enabled");

            const scoped = [
                { key: "a", pinned: true, windows: [{ workspaceId: 1, workspaceName: "1", monitorName: "DP-1" }] },
                { key: "b", pinned: false, windows: [{ workspaceId: 2, workspaceName: "2", monitorName: "DP-2" }] },
                { key: "c", pinned: false, windows: [{ workspaceId: -98, workspaceName: "special:minimized", monitorName: "DP-2" }] }
            ];
            const onWorkspace = Dock._scope(scoped, "workspace", "DP-1", 2);
            root.verify(onWorkspace.map(item => item.key).join(",") === "a,b,c", "workspace scope keeps pins, in-scope and minimized");
            root.verify(onWorkspace[0].windows.length === 0, "out-of-scope windows dropped from pinned item");
            const onMonitor = Dock._scope(scoped, "monitor", "DP-1", 1);
            root.verify(onMonitor.map(item => item.key).join(",") === "a,c", "monitor scope drops other monitors' apps");
            root.verify(Dock.isMinimized(scoped[2].windows[0]) && !Dock.isMinimized(scoped[0].windows[0]), "minimized detection");
            Dock.setOption("position", "top");
            root.verify(Dock.position === "bottom", "unsupported position ignored");
            Dock.setOption("position", "left");
            root.verify(Dock.position === "left", "position set");
            Dock.resetOptions();

            console.warn("DOCK_TEST_PASS");
        } catch (error) {
            console.error("DOCK_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
