import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    // Replays a sequence of [connectedIds, audioDevices] snapshots through
    // the Bluetooth-audio rule, returning every node it routed to.
    function replay(snapshots) {
        let state = { connected: [], pending: [] };
        const routes = [];
        for (const [ids, audio] of snapshots) {
            const step = Automations._bluetoothAudioStep(state, ids, audio);
            state = step.state;
            if (step.route) routes.push(step.route);
        }
        return routes;
    }

    Component.onCompleted: {
        try {
            const jbl = "34:51:6F:32:46:D6";
            const a2dp = [{ id: jbl, nodeName: "bluez_output.jbl.1" }];

            // Connect: node arrives after the BlueZ connection → routed once.
            let routes = root.replay([[[jbl], []], [[jbl], a2dp], [[jbl], a2dp]]);
            root.verify(JSON.stringify(routes) === JSON.stringify(["bluez_output.jbl.1"]), "connect routes once: " + routes);

            // Profile switch (Zoom opening the mic): the node drops and comes
            // back while the device stays connected → no re-route.
            routes = root.replay([[[jbl], a2dp], [[jbl], []], [[jbl], a2dp], [[jbl], []], [[jbl], a2dp]]);
            root.verify(routes.length === 1, "profile switch must not re-route: " + routes);

            // Disconnect then reconnect → routed again.
            routes = root.replay([[[jbl], a2dp], [[], []], [[jbl], []], [[jbl], a2dp]]);
            root.verify(routes.length === 2, "reconnect routes again: " + routes);

            // A non-audio device (mouse) connecting never routes.
            routes = root.replay([[["mouse"], []], [["mouse"], []]]);
            root.verify(routes.length === 0, "non-audio device: " + routes);

            // Fullscreen → DND clears only the DND it set itself.
            ShellState.dndEnabled = false;
            Automations.fullscreenRule = true;
            Automations._setFullscreen(true);
            root.verify(ShellState.dndEnabled, "fullscreen turns on DND");
            Automations._setFullscreen(false);
            root.verify(!ShellState.dndEnabled, "leaving fullscreen clears its DND");
            ShellState.dndEnabled = true;
            Automations._setFullscreen(true);
            Automations._setFullscreen(false);
            root.verify(ShellState.dndEnabled, "manual DND survives fullscreen");
            ShellState.dndEnabled = false;
            Automations.fullscreenRule = false;
            Automations._setFullscreen(true);
            root.verify(!ShellState.dndEnabled, "rule off does nothing");

            console.warn("AUTOMATIONS_TEST_PASS");
        } catch (error) {
            console.error("AUTOMATIONS_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
