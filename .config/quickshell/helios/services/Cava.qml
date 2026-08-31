pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Drives the island's media visualizer off real audio via cava's raw ascii
// output, instead of faking bar heights — only runs while something is
// actually playing so it isn't burning CPU on an idle desktop.
QtObject {
    id: root

    readonly property int barCount: 16
    readonly property int maxRange: 8
    property var bars: Array(barCount).fill(0)

    function downsample(values, count) {
        if (values.length <= count) return values;
        const bucket = values.length / count;
        const out = [];
        for (let i = 0; i < count; i++) {
            const start = Math.floor(i * bucket);
            const end = Math.floor((i + 1) * bucket);
            let sum = 0;
            for (let j = start; j < end; j++) sum += values[j];
            out.push(sum / Math.max(1, end - start));
        }
        return out;
    }

    readonly property bool anyPlaying: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.some(p => p.isPlaying);
    }

    property bool configReady: false
    readonly property string configPath: Quickshell.env("HOME") + "/.cache/helios/cava.conf"

    onAnyPlayingChanged: {
        if (root.anyPlaying) {
            if (root.configReady) proc.running = true;
        } else {
            proc.running = false;
            root.bars = Array(root.barCount).fill(0);
        }
    }

    property Process writer: Process {
        command: ["sh", "-c",
            "mkdir -p '" + Quickshell.env("HOME") + "/.cache/helios' && cat > '" + root.configPath + "' <<'EOF'\n" +
            // MiniVisualizer's own Behavior/NumberAnimation already
            // interpolates between updates, so 60fps of raw cava output was
            // just 60 array-reallocations + binding recomputes a second for
            // no visible gain over half that — the 90ms easing swallows the
            // difference.
            "[general]\nbars = " + root.barCount + "\nframerate = 30\n\n" +
            "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n" +
            "ascii_max_range = " + root.maxRange + "\nbar_delimiter = 59\nframe_delimiter = 10\nEOF"]
        onExited: {
            root.configReady = true;
            if (root.anyPlaying) proc.running = true;
        }
    }

    property Process proc: Process {
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            onRead: line => {
                const vals = line.split(";").filter(s => s.length > 0).map(Number);
                if (vals.length > 0) root.bars = vals;
            }
        }
    }

    Component.onCompleted: writer.running = true
}
