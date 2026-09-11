pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property string path: WallpaperLibrary.path
    readonly property string source: WallpaperLibrary.source
    readonly property bool isVideo: WallpaperLibrary.isVideo

    function select(path) {
        if (!WallpaperLibrary.setPath(path)) return false;
        WallpaperPlayback.apply(WallpaperLibrary.path, false);
        if (Themes.mode === "dynamic" && !WallpaperLibrary.isVideo)
            Themes.applyDynamic();
        return true;
    }

    function restore() {
        return WallpaperLibrary.path
            ? WallpaperPlayback.apply(WallpaperLibrary.path, true)
            : false;
    }

    function setFolder(path) {
        WallpaperLibrary.setFolder(path);
    }
}
