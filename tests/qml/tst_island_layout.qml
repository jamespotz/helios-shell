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
            root.verify(Config.widgetKeys.idle.includes("launcher") && Config.widgetKeys.peek.includes("launcher"), "Launcher available in both layouts");
            root.verify(Config.widgetShown("idle", "focusTimer") && !Config.widgetKeys.peek.includes("focusTimer"), "timer defaults on and is idle-only");
            Config.setOption("showIdleLauncher", true);
            root.verify(Config.widgetShown("idle", "launcher"), "Launcher toggle applies");
            Config.setOption("launcherIconMode", "custom");
            Config.setOption("launcherIconPath", "/tmp/logo.svg");
            root.verify(JSON.parse(Config._islandPreset()).options.launcherIconPath === "/tmp/logo.svg", "custom icon included in presets");
            Config.resetOptions(["showIdleLauncher", "launcherIconMode", "launcherIconPath"]);
            root.verify(Config.idleWidgetLayout.filter(k => k !== "launcher" && k !== "focusTimer").join(",") === "workspaces,tiledLayout,activeWindow,media,clock,weather,tray,clipboard,statusIndicators,|", "idle default keeps existing order");
            root.verify(Config.peekWidgetLayout.filter(k => k !== "launcher" && k !== "focusTimer").join(",") === "workspaces,tiledLayout,activeWindow,|,clock,weather,tray,clipboard,statusIndicators", "peek default matches clusters");

            root.verify(Config._sanitizeLayout("peek", ["clock", "bogus", "|", "clock", "|", "tray"]).join(",")
                === "clock,|,tray,workspaces,tiledLayout,activeWindow,weather,clipboard,statusIndicators,launcher", "drops unknown/duplicates, appends missing");
            root.verify(Config._sanitizeLayout("peek", ["clock"]).slice(-1)[0] === "|", "missing marker goes last");
            root.verify(Config._sanitizeLayout("idle", null).length === 12, "bad value falls back to default");
            root.verify(!Config._sanitizeLayout("peek", []).includes("media"), "media is idle-only");

            Config.moveWidget("idle", "clock", 0);
            root.verify(Config.idleWidgetLayout[0] === "clock", "move to front");
            Config.moveWidget("idle", "|", 1);
            root.verify(Config.idleWidgetLayout.slice(0, 3).join(",") === "clock,|,workspaces", "marker moves like a widget");
            Config.moveWidget("idle", "weather", 99);
            root.verify(Config.idleWidgetLayout.slice(-1)[0] === "weather", "move clamps to end");

            root.verify(Config.widgetShown("idle", "clock") === Config.showIdleClock, "idle toggle key");
            root.verify(Config.widgetShown("peek", "statusIndicators") === Config.showStatusIndicators, "peek toggle key");
            root.verify(Config.widgetShown("idle", "|"), "marker always shown");

            Config.resetOptions(["idleLayout"]);
            root.verify(Config.idleWidgetLayout.filter(k => k !== "launcher" && k !== "focusTimer").slice(-1)[0] === "|", "reset restores default");
            const release = LauncherIcon.parse('ID="fedora"\nLOGO=fedora-logo-icon\nNAME="Fedora"');
            root.verify(release.ID === "fedora" && release.LOGO === "fedora-logo-icon", "release parser handles quotes");
            root.verify(LauncherIcon.resolve(release, name => name === "fedora-logo-icon" ? "fedora.svg" : "") === "fedora.svg", "OS logo resolves through icon theme");
            root.verify(LauncherIcon.resolve({ ID: "arch" }, name => name === "archlinux-logo" ? "arch.svg" : "") === "arch.svg", "known distro fallback resolves");
            root.verify(LauncherIcon.resolve({}, name => "").endsWith("/data/linux.svg"), "unknown distro falls back to bundled Linux icon");

            console.warn("ISLAND_LAYOUT_TEST_PASS");
        } catch (error) {
            console.error("ISLAND_LAYOUT_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
