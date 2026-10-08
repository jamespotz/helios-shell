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
            Audio.clearOutputPreference(); verify(Audio.preferredOutputName === "", "service API");
            console.warn("AUDIO_OUTPUT_RULE_TEST_PASS");
        } catch (e) { console.error("AUDIO_OUTPUT_RULE_TEST_FAIL:", e.toString()); }
        exitDelay.start();
    }
}
