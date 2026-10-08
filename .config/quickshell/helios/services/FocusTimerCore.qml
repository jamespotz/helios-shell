import QtQuick

QtObject {
    id: root
    property double nowMs: Date.now()
    property var state: ({ status: "idle", deadlineMs: 0, remainingMs: 0, presetId: "", completionPending: false })
    readonly property double remainingMs: state.status === "running" ? Math.max(0, state.deadlineMs - nowMs) : state.remainingMs
    signal completed()

    function idle(pending) { return { status: "idle", deadlineMs: 0, remainingMs: 0, presetId: "", completionPending: !!pending }; }
    function restore(saved) {
        if (!saved || !["idle", "running", "paused"].includes(saved.status)
            || (saved.status === "running" && (!Number.isFinite(saved.deadlineMs) || saved.deadlineMs <= 0))
            || (saved.status === "paused" && (!Number.isFinite(saved.remainingMs) || saved.remainingMs <= 0))) {
            state = idle(false); return;
        }
        state = { status: saved.status, deadlineMs: saved.status === "running" ? saved.deadlineMs : 0,
            remainingMs: saved.status === "paused" ? saved.remainingMs : 0,
            presetId: typeof saved.presetId === "string" ? saved.presetId : "", completionPending: !!saved.completionPending };
        tick();
    }
    function start(minutes, presetId) {
        if (state.status !== "idle" || !Number.isFinite(minutes) || minutes <= 0) return false;
        state = { status: "running", deadlineMs: nowMs + minutes * 60000, remainingMs: 0, presetId: presetId || "", completionPending: false };
        return true;
    }
    function pause() {
        if (state.status !== "running") return false;
        tick();
        if (state.status !== "running") return false;
        state = Object.assign({}, state, { status: "paused", remainingMs: remainingMs, deadlineMs: 0 });
        return true;
    }
    function resume() {
        if (state.status !== "paused") return false;
        state = Object.assign({}, state, { status: "running", deadlineMs: nowMs + state.remainingMs, remainingMs: 0 });
        return true;
    }
    function extend(minutes) {
        if (!Number.isFinite(minutes) || minutes <= 0 || state.status === "idle") return false;
        tick();
        if (state.status === "idle") return false;
        state = state.status === "running" ? Object.assign({}, state, { deadlineMs: state.deadlineMs + minutes * 60000 })
            : Object.assign({}, state, { remainingMs: state.remainingMs + minutes * 60000 });
        return true;
    }
    function stop() { state = idle(false); }
    function tick() {
        if (state.status === "running" && state.deadlineMs <= nowMs) {
            state = idle(true);
            completed();
        }
    }
    function dismissCompletion() { state = Object.assign({}, state, { completionPending: false }); }
}
