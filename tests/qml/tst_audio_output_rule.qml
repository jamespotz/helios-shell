import QtQuick
import Quickshell
import Quickshell.Io
import services
ShellRoot {
    id: root
    AudioOutputRuleCore { id: rule }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    property Timer exitDelay: Timer { interval: 50; onTriggered: terminator.running = true }
    function verify(v, message) { if (!v) throw new Error(message); }
    // Replays [connectedIds, audioDevices] snapshots through the Bluetooth
    // reconnect rule, returning every node it routed to.
    function replay(snapshots) {
        let state = { connected: [], pending: [] };
        const routes = [];
        for (const [ids, audio] of snapshots) {
            const step = rule.bluetoothStep(state, ids, audio);
            state = step.state;
            if (step.route) routes.push(step.route);
        }
        return routes;
    }
    Component.onCompleted: {
        try {
            rule.preferredName = "headphones";
            verify(rule.update([], false) === "", "no routing before PipeWire sync");
            verify(rule.update(["headphones"], false) === "", "startup enumeration is not arrival");
            verify(rule.update(["headphones"], true) === "", "initial sync seeds connected sinks");
            verify(!rule.canRouteConnection("headphones", true), "delayed Bluetooth startup connection does not override manual output");
            verify(!rule.canRouteConnection("headphones", false), "Bluetooth routing waits for PipeWire sync");
            rule.update([], true);
            verify(rule.update(["headphones"], true) === "headphones", "post-sync reconnect routes");
            verify(rule.canRouteConnection("headphones", true), "Bluetooth actual reconnect may route");
            rule.seed(["speakers", "headphones"]);
            verify(rule.arrived(["speakers", "headphones"]) === "", "startup keeps manual output");
            verify(rule.arrived(["speakers", "headphones", "other"]) === "", "unrelated arrival leaves manual output");
            rule.arrived(["speakers"]);
            verify(rule.arrived(["speakers", "headphones"]) === "headphones", "reconnect selects preferred sink");
            verify(rule.arrived(["speakers", "headphones"]) === "", "route once");
            verify(rule.prefer("speakers", ["speakers", "headphones"]) === "speakers", "explicit selection immediate");
            rule.prefer("", ["speakers"]); verify(rule.arrived(["speakers", "headphones"]) === "", "cleared rule");
            rule.preferredName = "exact-name"; rule.seed([]);
            verify(rule.arrived(["other-exact-name"]) === "", "exact matching only");
            const jbl = "34:51:6F:32:46:D6";
            const a2dp = [{ id: jbl, nodeName: "bluez_output.jbl.1" }];
            let routes = replay([[[jbl], []], [[jbl], a2dp], [[jbl], a2dp]]);
            verify(JSON.stringify(routes) === JSON.stringify(["bluez_output.jbl.1"]), "connect routes once: " + routes);
            // Headset mode switch: the node drops and returns while connected.
            routes = replay([[[jbl], a2dp], [[jbl], []], [[jbl], a2dp], [[jbl], []], [[jbl], a2dp]]);
            verify(routes.length === 1, "headset mode switch must not re-route: " + routes);
            routes = replay([[[jbl], a2dp], [[], []], [[jbl], []], [[jbl], a2dp]]);
            verify(routes.length === 2, "reconnect routes again: " + routes);
            routes = replay([[["mouse"], []], [["mouse"], []]]);
            verify(routes.length === 0, "non-audio device: " + routes);

            verify(rule.isBluetoothSink("x", { "device.api": "BlueZ5" }), "device.api, any case");
            verify(rule.isBluetoothSink("x", { "device.bus": "bluetooth" }), "device.bus");
            verify(rule.isBluetoothSink("x", { "api.bluez5.address": "11:22" }), "address");
            verify(rule.isBluetoothSink("bluez_output.11_22.1", {}), "name only");
            verify(!rule.isBluetoothSink("alsa_output.pci", { "device.bus": "pci" }), "wired sink");
            Audio.clearOutputPreference(); verify(Audio.preferredOutputName === "", "service API");
            console.warn("AUDIO_OUTPUT_RULE_TEST_PASS");
        } catch (e) { console.error("AUDIO_OUTPUT_RULE_TEST_FAIL:", e.toString()); }
        exitDelay.start();
    }
}
