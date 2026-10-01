pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var os: ({})
    readonly property string osSource: root.resolve(root.os, name => Quickshell.iconPath(name, true))
    readonly property string source: Config.launcherIconMode === "custom" && Config.launcherIconPath
        ? "file://" + Config.launcherIconPath.split("/").map(part => encodeURIComponent(part)).join("/") : root.osSource
    readonly property bool picking: picker.running

    function chooseImage() { if (!root.picking) picker.running = true; }

    property Process picker: Process {
        command: ["zenity", "--file-selection", "--title=Choose Launcher icon", "--file-filter=Images | *.svg *.png *.jpg *.jpeg *.webp"]
        stdout: StdioCollector {
            onStreamFinished: { const picked = text.trim(); if (picked) Config.setOption("launcherIconPath", picked); }
        }
        onRunningChanged: ShellState.launcherIconPickerOpen = running
    }

    function parse(text) {
        const values = {};
        for (const line of text.split("\n")) {
            const match = line.match(/^(ID|LOGO)=(.*)$/);
            if (match) values[match[1]] = match[2].replace(/^["']|["']$/g, "");
        }
        return values;
    }
    function resolve(values, lookup) {
        const names = { fedora: "fedora-logo-icon", arch: "archlinux-logo", ubuntu: "ubuntu-logo",
            debian: "debian-logo", linuxmint: "linuxmint-logo", nixos: "nix-snowflake", opensuse: "distributor-logo" };
        for (const name of [values.LOGO, names[values.ID], "distributor-logo", "linux"])
            if (name) { const path = lookup(name); if (path) return path; }
        return Qt.resolvedUrl("../data/linux.svg").toString();
    }
    property FileView release: FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: root.os = root.parse(text())
    }
}
