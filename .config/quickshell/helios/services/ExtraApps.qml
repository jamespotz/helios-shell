pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Supplementary desktop-entry scan for locations Quickshell's own
// DesktopEntries service doesn't reliably include. Flatpak's already covered
// — its export dirs are normally on XDG_DATA_DIRS, which DesktopEntries
// reads — but snapd registers its desktop files under /var/lib/snapd/desktop
// without reliably adding that to XDG_DATA_DIRS for non-login sessions, so
// Launcher merges this in alongside DesktopEntries.applications.
QtObject {
    id: root

    property var list: []

    readonly property Process scanner: Process {
        // \x1e (record separator) delimits "path, then its content" pairs so
        // one process call can hand back every file without needing to spawn
        // a child per .desktop file. Globs on a missing directory just expand
        // to nothing, so this is a no-op where snapd isn't installed.
        command: ["sh", "-c",
            "for f in /var/lib/snapd/desktop/applications/*.desktop; do " +
            "[ -f \"$f\" ] && printf '\\036%s\\036' \"$f\" && cat \"$f\"; done 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseAll(text)
        }
    }

    function parseAll(output) {
        const chunks = output.split("").filter(s => s.length > 0);
        const entries = [];
        // Chunks alternate: path, content, path, content, ...
        for (let i = 0; i + 1 < chunks.length; i += 2) {
            const entry = root.parseDesktopFile(chunks[i + 1]);
            if (entry) entries.push(entry);
        }
        root.list = entries;
    }

    function parseDesktopFile(text) {
        const lines = text.split("\n");
        let inEntry = false;
        const fields = {};

        for (const raw of lines) {
            const line = raw.trim();
            if (line === "[Desktop Entry]") { inEntry = true; continue; }
            if (line.startsWith("[")) { inEntry = false; continue; }
            if (!inEntry || !line || line.startsWith("#")) continue;

            const eq = line.indexOf("=");
            if (eq < 0) continue;
            const key = line.slice(0, eq).trim();
            // First occurrence wins; locale-suffixed keys like Name[de] are
            // stored under their own key and never read, so plain Name stays
            // the untranslated default.
            if (key in fields) continue;
            fields[key] = line.slice(eq + 1).trim();
        }

        if (!fields.Name || !fields.Exec) return null;
        if (fields.NoDisplay === "true" || fields.Hidden === "true") return null;

        const execCmd = fields.Exec.replace(/%[fFuUdDnNickvm]/g, "").trim();
        const isTerminal = fields.Terminal === "true";

        return {
            name: fields.Name,
            genericName: fields.GenericName || "",
            icon: fields.Icon || "",
            keywords: (fields.Keywords || "").split(";").filter(k => k.length > 0),
            noDisplay: false,
            execute: function() {
                Quickshell.execDetached(isTerminal
                    ? [Config.terminal, "-e", "sh", "-c", execCmd]
                    : ["sh", "-c", execCmd]);
            }
        };
    }

    Component.onCompleted: scanner.running = true
}
