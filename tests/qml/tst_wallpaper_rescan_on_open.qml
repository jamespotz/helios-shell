import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "services" as Services
import "modules/bar" as BarModules

ShellRoot {
    id: root

    property int phase: 0
    readonly property string wallpaperDir: Quickshell.env("WALLPAPER_RESCAN_TEST_DIR")
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }

    Window {
        visible: true
        width: 600
        height: 500

        BarModules.WallpaperSettings {
            anchors.centerIn: parent
        }
    }

    Process {
        id: setup
        command: ["sh", "-c", "mkdir -p \"$0\" && touch \"$0/first.jpg\"", root.wallpaperDir]
        onExited: Services.WallpaperLibrary.setFolder(root.wallpaperDir)
    }

    Process {
        id: addWallpaper
        command: ["touch", root.wallpaperDir + "/second.jpg"]
        onExited: Services.IslandNavigation.show("test", "wallpaper")
    }

    Connections {
        target: Services.WallpaperLibrary
        function onImagesChanged() {
            if (root.phase === 0 && Services.WallpaperLibrary.images.length === 1) {
                root.phase = 1;
                addWallpaper.running = true;
            } else if (root.phase === 1 && Services.WallpaperLibrary.images.length === 2) {
                console.warn("WALLPAPER_RESCAN_ON_OPEN_TEST_PASS");
                root.terminator.running = true;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: {
            console.error("WALLPAPER_RESCAN_ON_OPEN_TEST_FAIL");
            root.terminator.running = true;
        }
    }

    Component.onCompleted: setup.running = true
}
