import QtQuick
import Quickshell
import Quickshell.Io
import services
ShellRoot {
    id: root
    property string mode: Quickshell.env("HELIOS_TIMER_MODE")
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    function verify(v, message) { if (!v) throw new Error(message); }
    Component.onCompleted: { FocusTimer.state; Config.settingsFile; }
    Timer {
        interval: 150; running: true
        onTriggered: {
            try {
                if (mode === "running-write") { verify(FocusTimer.start(25, "deleted-preset"), "start"); }
                else if (mode === "running-read") { verify(FocusTimer.state.status === "running" && FocusTimer.remainingMs > 1490000 && FocusTimer.remainingMs <= 1500000, "running session restored with deadline"); FocusTimer.stop(); }
                else if (mode === "paused-write") { FocusTimer.start(25, ""); FocusTimer.pause(); FocusTimer.extend(5); }
                else if (mode === "paused-read") { verify(FocusTimer.state.status === "paused" && FocusTimer.remainingMs > 1799000 && FocusTimer.remainingMs <= 1800000, "paused session restored exactly"); FocusTimer.stop(); }
                else if (mode === "expired-write") { FocusTimer.core.nowMs = Date.now(); FocusTimer.core.restore({status: "running", deadlineMs: Date.now() - 100, remainingMs: 0, presetId: "", completionPending: false}); }
                else if (mode === "expired-read") { verify(FocusTimer.state.status === "idle" && FocusTimer.completionPending, "completion pending restored once"); FocusTimer.dismissCompletion(); }
                else if (mode === "dismissed-read") { verify(FocusTimer.state.status === "idle" && !FocusTimer.completionPending, "dismissed completion does not return"); }
                else if (mode === "break-write") { Config.setOption("shortBreakMinutes", 8); verify(FocusTimer.startBreak("short"), "start persisted break"); FocusTimer.pause(); }
                else if (mode === "break-read") { verify(FocusTimer.state.kind === "short-break" && FocusTimer.state.status === "paused" && FocusTimer.remainingMs > 479000 && FocusTimer.remainingMs <= 480000, "break kind and duration restored"); verify(Config.shortBreakMinutes === 8, "break setting restored"); FocusTimer.stop(); }
                else if (mode === "pomodoro-write") { verify(FocusTimer.start(50, ""), "start persisted Pomodoro"); FocusTimer.pause(); }
                else if (mode === "pomodoro-read") {
                    verify(FocusTimer.state.status === "paused" && FocusTimer.state.nextBreak === "long", "automatic break choice restored");
                    FocusTimer.resume(); FocusTimer.core.nowMs = FocusTimer.state.deadlineMs; FocusTimer.core.tick();
                    verify(FocusTimer.state.kind === "long-break" && FocusTimer.remainingMs === Config.longBreakMinutes * 60000, "restored Pomodoro starts break"); FocusTimer.stop();
                }
                done.start();
            } catch (e) { console.error("FOCUS_TIMER_PERSISTENCE_TEST_FAIL:", mode, e.toString()); terminator.running = true; }
        }
    }
    Timer {
        id: done; interval: mode === "break-write" ? 450 : 150
        onTriggered: {
            if (FocusTimer.error) console.error("FOCUS_TIMER_PERSISTENCE_TEST_FAIL:", FocusTimer.error);
            else console.warn("FOCUS_TIMER_PERSISTENCE_TEST_PASS", mode);
            terminator.running = true;
        }
    }
}
