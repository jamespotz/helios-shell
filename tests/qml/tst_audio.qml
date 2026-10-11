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
            const nodes = [
                { name: "alsa_output.pci.analog", description: "Built-in Audio", nickname: "" },
                { name: "bluez_output.jbl.1", description: "JBL Flip 5", nickname: "Speaker" }
            ];
            root.verify(Audio.findNode(nodes, "bluez_output.jbl.1") === nodes[1], "exact node name");
            root.verify(Audio.findNode(nodes, "built-in") === nodes[0], "description substring, case-insensitive");
            root.verify(Audio.findNode(nodes, "speaker") === nodes[1], "nickname substring");
            root.verify(!Audio.findNode(nodes, "usb headset"), "no match");
            root.verify(!Audio.interactionOpen, "idle does not wake audio");
            Audio.setIslandExpanded("one", true);
            Audio.setIslandExpanded("two", true);
            Audio.setIslandExpanded("one", false);
            root.verify(Audio.interactionOpen, "second expanded Island keeps audio awake");
            Audio.setIslandExpanded("two", false);
            root.verify(!Audio.interactionOpen, "closing all Islands releases audio");
            ShellState.settingsOpen = true;
            root.verify(Audio.interactionOpen, "Settings wakes audio");
            ShellState.settingsOpen = false;
            IslandNavigation.show("one", "volume");
            root.verify(Audio.interactionOpen, "destination wakes audio");
            IslandNavigation.close();
            root.verify(!Audio.interactionOpen, "closing destination releases audio");
            console.warn("AUDIO_TEST_PASS");
        } catch (error) {
            console.error("AUDIO_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
