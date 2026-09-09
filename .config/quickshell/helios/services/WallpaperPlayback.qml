pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

QtObject {
    id: root

    property int operationId: 0
    property string pendingPath: ""
    property bool pendingVideo: false
    property string transitionType: "simple"
    property bool daemonStopped: false
    property int retryCount: 0
    property string status: "idle"
    property string activePath: ""
    property string error: ""

    function apply(path, restore) {
        if (!path) return false;
        let resolved = path;
        if (resolved.startsWith("~")) resolved = Quickshell.env("HOME") + resolved.slice(1);
        root.operationId++;
        root.pendingPath = resolved;
        root.pendingVideo = ["mp4", "webm", "mkv", "mov"].includes(resolved.split(".").pop().toLowerCase());
        root.transitionType = restore ? "simple" : Config.wallpaperTransitionStyle;
        root.retryCount = 0;
        root.error = "";
        root.status = "pending";
        retryTimer.stop();
        respawnTimer.stop();
        videoKill.operationId = root.operationId;
        videoKill.running = false;
        videoKill.running = true;
        return true;
    }

    function _applyImage(id) {
        if (id !== root.operationId) return;
        imageApply.operationId = id;
        imageApply.command = ["awww", "img", root.pendingPath,
            "--transition-type", root.transitionType, "--transition-step", 255, "--transition-fps", 144];
        imageApply.running = false;
        imageApply.running = true;
    }

    property Process videoKill: Process {
        property int operationId: 0
        command: ["pkill", "-KILL", "-x", "mpvpaper"]
        onExited: {
            if (videoKill.operationId !== root.operationId) return;
            if (root.pendingVideo) {
                videoPlayer.command = ["mpvpaper", "-o", "no-audio loop panscan=1.0 hwdec=auto", "*", root.pendingPath];
                videoPlayer.running = false;
                videoPlayer.running = true;
                daemonKill.running = false;
                daemonKill.running = true;
                root.daemonStopped = true;
                root.activePath = root.pendingPath;
                root.status = "active";
            } else if (root.daemonStopped) {
                root.daemonStopped = false;
                daemon.running = false;
                daemon.running = true;
                respawnTimer.operationId = root.operationId;
                respawnTimer.start();
            } else {
                root._applyImage(root.operationId);
            }
        }
    }

    property Process daemonKill: Process { command: ["awww", "kill"] }
    property Process videoPlayer: Process {}
    property Process daemon: Process { command: ["awww-daemon"]; running: true }

    property Timer respawnTimer: Timer {
        property int operationId: 0
        interval: 400
        onTriggered: root._applyImage(respawnTimer.operationId)
    }
    property Timer retryTimer: Timer {
        property int operationId: 0
        interval: 500
        onTriggered: root._applyImage(retryTimer.operationId)
    }

    property Process imageApply: Process {
        property int operationId: 0
        onExited: exitCode => {
            if (imageApply.operationId !== root.operationId) return;
            if (exitCode === 0) {
                root.retryCount = 0;
                root.activePath = root.pendingPath;
                root.status = "active";
                return;
            }
            if (root.retryCount < 3) {
                root.retryCount++;
                daemon.running = false;
                daemon.running = true;
                retryTimer.operationId = root.operationId;
                retryTimer.start();
                return;
            }
            root.status = "failed";
            root.error = "Failed to apply wallpaper";
        }
    }
}
