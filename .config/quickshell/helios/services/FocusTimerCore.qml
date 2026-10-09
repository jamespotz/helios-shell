import QtQuick

QtObject {
    id: root
    property double nowMs: Date.now()
    property var state: ({ status: "idle", deadlineMs: 0, remainingMs: 0, presetId: "", kind: "focus", nextBreak: "", completionPending: false })
    readonly property double remainingMs: state.status === "running" ? Math.max(0, state.deadlineMs - nowMs) : state.remainingMs
    signal completed(string kind, var nextBreak)

    function idle(pending, kind) { return { status: "idle", deadlineMs: 0, remainingMs: 0, presetId: "", kind: kind || "focus", nextBreak: "", completionPending: !!pending }; }
    function restore(saved) {
        if (!saved || !["idle", "running", "paused"].includes(saved.status)
            || (saved.status === "running" && (!Number.isFinite(saved.deadlineMs) || saved.deadlineMs <= 0))
            || (saved.status === "paused" && (!Number.isFinite(saved.remainingMs) || saved.remainingMs <= 0))) {
            state = idle(false); return;
        }
        state = { status: saved.status, deadlineMs: saved.status === "running" ? saved.deadlineMs : 0,
            remainingMs: saved.status === "paused" ? saved.remainingMs : 0,
            kind: ["short-break", "long-break", "extended-break", "custom-break"].includes(saved.kind) ? saved.kind : "focus",
            nextBreak: ["short", "long", "extended"].includes(saved.nextBreak) || (Number.isInteger(saved.nextBreak) && saved.nextBreak >= 1 && saved.nextBreak <= 60) ? saved.nextBreak : "",
            presetId: typeof saved.presetId === "string" ? saved.presetId : "", completionPending: !!saved.completionPending };
        tick();
    }
    function start(minutes, presetId, kind, nextBreak) {
        if (state.status !== "idle" || !Number.isFinite(minutes) || minutes <= 0) return false;
        state = { status: "running", deadlineMs: nowMs + minutes * 60000, remainingMs: 0, presetId: presetId || "", kind: kind || "focus", nextBreak: nextBreak || "", completionPending: false };
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
            const kind = state.kind;
            const nextBreak = state.nextBreak;
            state = idle(true, kind);
            completed(kind, nextBreak);
        }
    }
    function dismissCompletion() { state = Object.assign({}, state, { completionPending: false }); }
}
