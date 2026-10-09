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
            verify(Config.shortBreakMinutes === 5 && Config.longBreakMinutes === 15, "break defaults");
            Config.setOption("shortBreakMinutes", 7);
            Config.setOption("longBreakMinutes", 20);
            verify(FocusTimer.startBreak("short"), "start short break");
            verify(FocusTimer.state.kind === "short-break" && FocusTimer.remainingMs === 420000, "configured short break");
            verify(!FocusTimer.startBreak("long"), "break cannot replace active session");
            FocusTimer.pause();
            const breakState = JSON.parse(JSON.stringify(FocusTimer.state));
            FocusTimer.core.restore(breakState);
            verify(FocusTimer.state.kind === "short-break" && FocusTimer.state.status === "paused", "restore break kind");
            FocusTimer.resume();
            FocusTimer.core.nowMs = FocusTimer.state.deadlineMs;
            FocusTimer.core.tick();
            verify(FocusTimer.completionPending && FocusTimer.state.kind === "short-break", "break completion keeps kind");
            verify(FocusTimer.startBreak("long"), "start long break from completion");
            verify(FocusTimer.state.kind === "long-break" && FocusTimer.remainingMs === 1200000, "configured long break");
            FocusTimer.stop();
            verify(!FocusTimer.startBreak("invalid"), "reject unknown break");
            timer.restore({status: "paused", remainingMs: 5000});
            verify(timer.state.kind === "focus", "legacy timers remain focus sessions");
            verify(FocusTimer.start(25, ""), "start Pomodoro");
            FocusTimer.pause(); FocusTimer.resume(); FocusTimer.extend(5);
            FocusTimer.core.nowMs = FocusTimer.state.deadlineMs;
            FocusTimer.core.tick();
            verify(FocusTimer.state.status === "running" && FocusTimer.state.kind === "short-break" && FocusTimer.remainingMs === 420000, "25 minute focus automatically starts configured short break after extend");
            FocusTimer.core.nowMs = FocusTimer.state.deadlineMs;
            FocusTimer.core.tick();
            verify(!FocusTimer.active && FocusTimer.completionPending, "break ends without restarting focus");
            verify(FocusTimer.start(50, ""), "start long focus");
            const pomodoro = JSON.parse(JSON.stringify(FocusTimer.state));
            FocusTimer.core.nowMs = pomodoro.deadlineMs;
            FocusTimer.core.restore(pomodoro);
            verify(FocusTimer.state.kind === "long-break" && FocusTimer.remainingMs === 1200000, "restored 50 minute focus automatically starts configured long break");
            FocusTimer.stop();
            verify(FocusTimer.start(10, ""), "custom focus");
            FocusTimer.core.nowMs = FocusTimer.state.deadlineMs; FocusTimer.core.tick();
            verify(!FocusTimer.active && FocusTimer.completionPending, "custom focus preserves completion alert");
            FocusTimer.stop();
            verify(Config.extendedBreakMinutes === 20, "90 minute session defaults to 20 minute break");
            verify(FocusTimer.start(90, ""), "start 90 minute focus");
            const extendedSession = JSON.parse(JSON.stringify(FocusTimer.state));
            FocusTimer.core.nowMs = extendedSession.deadlineMs;
            FocusTimer.core.restore(extendedSession);
            verify(FocusTimer.state.kind === "extended-break" && FocusTimer.remainingMs === 1200000, "restored 90 minute focus starts 20 minute break");
            FocusTimer.stop();
            verify(!FocusTimer.startCustom(0, 10, "") && !FocusTimer.startCustom(30, 0, ""), "reject invalid custom durations");
            verify(FocusTimer.startCustom(35, 12, ""), "start custom pair");
            const customSession = JSON.parse(JSON.stringify(FocusTimer.state));
            FocusTimer.core.nowMs = customSession.deadlineMs;
            FocusTimer.core.restore(customSession);
            verify(FocusTimer.state.kind === "custom-break" && FocusTimer.remainingMs === 720000, "restored custom focus starts chosen break");
            FocusTimer.stop();
            console.warn("FOCUS_TIMER_TEST_PASS");
        } catch (e) { console.error("FOCUS_TIMER_TEST_FAIL:", e.toString()); }
        exitDelay.start();
    }
}
