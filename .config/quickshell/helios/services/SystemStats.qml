pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live CPU/memory/GPU/disk/network stats for modules/bar/SystemMonitorTab.qml,
// sourced from the user's system-info.py helper (same directory as that tab)
// which polls psutil + nvidia-smi and prints one pretty-printed JSON object
// every 5s on stdout. start()/stop() are idempotent — the tab calls stop()
// both when its "Pause live updates" toggle is used and when it closes, so
// the python process (and its nvidia-smi child) only ever runs while the
// tab is open and unpaused.
QtObject {
    id: root

    property bool ready: false
    property var cpu: ({ usage_percent: 0, per_core: [], frequency_mhz: 0 })
    property var memory: ({ usage_percent: 0, used_gb: 0, total_gb: 0 })
    property var disk: ({ read_mb: 0, write_mb: 0 })
    property var network: ({ sent_mb: 0, received_mb: 0 })
    property var gpu: null // null when no GPU / nvidia-smi unavailable

    function start() { proc.running = true; }
    function stop() {
        proc.running = false;
        root._buf = "";
        root._depth = 0;
    }

    property string _buf: ""
    property int _depth: 0

    property Process proc: Process {
        // -u: unbuffered stdout — piped (non-tty) stdout is block-buffered by
        // default, so without this the script's prints sit in its internal
        // buffer for a long time before SplitParser ever sees a line.
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/system-info.py"]
        stdout: SplitParser {
            onRead: line => {
                for (let i = 0; i < line.length; i++) {
                    const ch = line[i];
                    if (ch === "{") root._depth++;
                    else if (ch === "}") root._depth--;
                }
                root._buf += line + "\n";
                if (root._depth === 0 && root._buf.trim().length > 0) {
                    try {
                        const data = JSON.parse(root._buf);
                        root.cpu = data.cpu;
                        root.memory = data.memory;
                        root.disk = data.disk;
                        root.network = data.network;
                        root.gpu = data.gpu;
                        root.ready = true;
                    } catch (e) {
                        // Partial/malformed block — drop it and wait for the next.
                    }
                    root._buf = "";
                }
            }
        }
    }
}
