import QtQuick
import Quickshell
import Quickshell.Io
import services
ShellRoot {
    id: root
    property int completions: 0
    FocusTimerCore { id: timer; nowMs: 1000; onCompleted: root.completions++ }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    property Timer exitDelay: Timer { interval: 50; onTriggered: terminator.running = true }
    function verify(v, message) { if (!v) throw new Error(message); }
    Component.onCompleted: {
        try {
            verify(FocusTimer.state.status === "idle", "service initialized");
            verify(timer.start(25, "focus"), "start");
            verify(timer.state.deadlineMs === 1501000, "25 minute deadline");
            verify(!timer.start(50, ""), "reject second session");
            timer.nowMs = 61000; timer.pause();
            verify(timer.state.remainingMs === 1440000 && timer.state.status === "paused", "pause");
            timer.nowMs = 100000; timer.resume();
            verify(timer.state.deadlineMs === 1540000, "resume");
            timer.extend(5); verify(timer.state.deadlineMs === 1840000, "extend");
            timer.nowMs = 2000000; timer.tick(); timer.tick();
            verify(completions === 1 && timer.state.completionPending, "complete once after delayed tick");
            const saved = JSON.parse(JSON.stringify(timer.state));
            timer.restore(saved); timer.tick(); verify(completions === 1, "no duplicate restored completion");
            timer.dismissCompletion(); timer.restore(timer.state); verify(!timer.state.completionPending, "acknowledgement persists");
            timer.nowMs = 1000; timer.restore({status: "running", deadlineMs: 500, remainingMs: 0, presetId: "deleted", completionPending: false});
            verify(completions === 2 && timer.state.status === "idle", "expired restoration");
            timer.restore({status: "paused", deadlineMs: 0, remainingMs: 5000, presetId: "", completionPending: false});
            timer.nowMs = 999999; timer.tick(); verify(timer.remainingMs === 5000, "paused restore");
            timer.stop(); verify(timer.state.status === "idle" && !timer.state.completionPending, "stop");
            timer.restore({status: "running", deadlineMs: -1}); verify(timer.state.status === "idle", "reject invalid persistence");
            verify(!timer.start(-1, "") && !timer.start(NaN, ""), "reject invalid duration");
            console.warn("FOCUS_TIMER_TEST_PASS");
        } catch (e) { console.error("FOCUS_TIMER_TEST_FAIL:", e.toString()); }
        exitDelay.start();
    }
}
