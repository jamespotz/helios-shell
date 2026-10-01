import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI
import "modules/settings" as SettingsUI

ShellRoot {
    id: root
    function verify(value, message) { if (!value) throw new Error(message); }
    function findButton(item) {
        if (item.text === "Choose icon image" && item.clicked) return item;
        for (const child of item.children || []) { const found = findButton(child); if (found) return found; }
        return null;
    }
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }
    FloatingWindow {
        visible: true
        width: 800
        height: 600
        IslandUI.LauncherWidget { id: button; targetScreen: ({ name: "test-screen" }) }
        Loader {
            id: settings
            active: !ShellState.launcherIconPickerOpen
            sourceComponent: Component { SettingsUI.IslandSettings {} }
        }
        Image { id: selectedImage; source: LauncherIcon.source }
    }
    readonly property Timer check: Timer {
        interval: 150
        onTriggered: {
            try {
                button.clicked();
                root.verify(IslandNavigation.panelOpenFor("test-screen") && IslandNavigation.destinationId === "launcher" && Launcher.view === "grid", "button opens app grid on its screen");
                Config.setOption("launcherIconMode", "custom");
                root.findButton(settings.item).clicked();
                IslandNavigation.close();
                finish.start();
                return;
            } catch (error) { console.error("LAUNCHER_WIDGET_TEST_FAIL:", error.toString()); }
            root.terminateDelay.start();
        }
    }
    Component.onCompleted: root.check.start()
    readonly property Timer finish: Timer {
        interval: 600
        onTriggered: {
            try {
                root.verify(!ShellState.launcherIconPickerOpen && settings.item, "settings returns after picker finishes");
                root.verify(Config.launcherIconPath === Quickshell.env("HELIOS_TEST_ICON"), "picker persists selection after settings page unloads");
                root.verify(selectedImage.status === Image.Ready, "custom image with reserved filename characters loads");
                LauncherIcon.picker.command = ["sh", "-c", "exit 0"];
                LauncherIcon.chooseImage();
                cancelCheck.start();
                return;
            } catch (error) { console.error("LAUNCHER_WIDGET_TEST_FAIL:", error.toString()); }
            root.terminateDelay.start();
        }
    }
    readonly property Timer cancelCheck: Timer {
        interval: 150
        onTriggered: {
            try {
                root.verify(!ShellState.launcherIconPickerOpen && settings.item, "cancelled picker restores settings");
                root.verify(Config.launcherIconPath === Quickshell.env("HELIOS_TEST_ICON"), "cancelled picker preserves existing icon");
                console.warn("LAUNCHER_WIDGET_TEST_PASS");
            } catch (error) { console.error("LAUNCHER_WIDGET_TEST_FAIL:", error.toString()); }
            root.terminateDelay.start();
        }
    }
}
