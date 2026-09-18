pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Utils.js" as Utils

// Cross-window link between the live annotation drawing surface
// (modules/annotate/AnnotateOverlay.qml, a fullscreen transparent
// PanelWindow) and its toolbar (hosted in the main island, a different
// PanelWindow entirely). IslandNavigation is the single source of truth
// for open/closed — both surfaces just read it — so there's no second
// flag that can drift out of sync.
QtObject {
    id: root

    readonly property bool open: IslandNavigation.open && IslandNavigation.destinationId === "annotate"
    readonly property bool editingScreenshot: root.screenshotPath.length > 0
    property Item canvas: null
    property string screenshotPath: ""
    property string returnScreen: ""
    property int screenshotRevision: 0
    property bool savingScreenshot: false
    property bool screenshotSaveFailed: false
    property bool overlayVisible: false

    onOpenChanged: {
        if (root.open)
            root.overlayVisible = true;
        else if (root.editingScreenshot)
            root._resetScreenshotState();
    }

    function toggle() {
        const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
        IslandNavigation.toggle(screen.name, "annotate");
    }

    function beginScreenshot(screenName, path) {
        if (!screenName || !path)
            return false;
        root.screenshotPath = path;
        root.returnScreen = screenName;
        root.screenshotSaveFailed = false;
        if (IslandNavigation.show(screenName, "annotate"))
            return true;
        root.screenshotPath = "";
        root.returnScreen = "";
        return false;
    }

    function saveScreenshot() {
        if (!root.editingScreenshot || !root.canvas || root.savingScreenshot)
            return false;
        root.savingScreenshot = true;
        root.screenshotSaveFailed = false;
        root.canvas.saveToFile(root.screenshotPath,
            () => root.overlayVisible = false,
            saved => {
                root.savingScreenshot = false;
                if (!saved) {
                    root.screenshotSaveFailed = true;
                    root.overlayVisible = true;
                    return;
                }
                root.screenshotRevision++;
                root._finishScreenshot();
            });
        return true;
    }

    function cancelScreenshot() {
        if (!root.editingScreenshot)
            return;
        root._finishScreenshot();
    }

    function _finishScreenshot() {
        const screen = root.returnScreen;
        root._resetScreenshotState();
        IslandNavigation.show(screen, "screenshot");
    }

    function _resetScreenshotState() {
        root.screenshotPath = "";
        root.returnScreen = "";
        root.savingScreenshot = false;
        root.screenshotSaveFailed = false;
        root.overlayVisible = false;
    }

    function close() {
        if (root.editingScreenshot)
            root.cancelScreenshot();
        else if (root.open)
            IslandNavigation.close();
    }
}
