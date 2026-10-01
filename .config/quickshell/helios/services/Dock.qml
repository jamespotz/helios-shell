pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Qt.labs.folderlistmodel

// Pinned + running apps for the Dock, and the per-screen overlap test that
// drives its intellihide. Windows come from Hyprland's toplevels; geometry
// (lastIpcObject) is refreshed on window/workspace events, never polled.
QtObject {
    id: root

    // Desktop-entry keys (entry.id, or name for ExtraApps entries) in order.
    property var pins: []
    // Screen names the Dock is turned off on.
    property var hiddenScreens: []
    // Desktop-entry keys of recently focused or launched apps, most recent
    // first. Recorded even while showRecents is off, so turning it on
    // shows something straight away.
    property var recents: []
    readonly property int _recentsKept: 20

    // Every user option: default, plus [min, max] for numbers or the
    // allowed values for choices. setOption() clamps/validates against
    // this, and it drives saving and loading.
    readonly property var options: ({
        enabled: { value: true },
        position: { value: "bottom", choices: ["bottom", "left", "right"] },
        alignment: { value: "center", choices: ["start", "center", "end"] },
        // What clicking an app that already has focus does.
        focusedClick: { value: "cycle", choices: ["cycle", "minimize", "none"] },
        middleClick: { value: "new", choices: ["new", "close"] },
        // Which running windows a screen's Dock shows.
        runningScope: { value: "all", choices: ["all", "monitor", "workspace"] },
        launchBounce: { value: true },
        showTooltips: { value: true },
        revealDuration: { value: 280, range: [0, 600] },
        // "intellihide" = hide when a window would cover the Dock,
        // "always" = only on screen-edge hover, "never" = always shown and
        // reserves its space.
        autohide: { value: "intellihide", choices: ["intellihide", "always", "never"] },
        hideDelay: { value: 260, range: [0, 1500] },
        showRunning: { value: true },
        // Recently used apps that are neither pinned nor running, after
        // the running apps.
        showRecents: { value: false },
        recentCount: { value: 3, range: [1, 10] },
        // Mouse wheel over a running app cycles through its windows.
        scrollCycle: { value: false },
        // Liquid Glass for the Dock: "follow" the shell-wide toggle, or
        // force it "on"/"off".
        glass: { value: "follow", choices: ["follow", "on", "off"] },
        showIndicators: { value: true },
        // "dot" grows longer for several windows, "line" is a wide bar,
        // "windows" shows one dot per window (up to 3).
        indicatorStyle: { value: "dot", choices: ["dot", "line", "windows"] },
        showBadges: { value: true },
        showAppsButton: { value: true },
        showSettingsButton: { value: true },
        showTrash: { value: false },
        previews: { value: true },
        magnify: { value: true },
        magnifyScale: { value: 1.45, range: [1.1, 2], step: 0.05 },
        iconSize: { value: 44, range: [32, 64] },
        iconSpacing: { value: 6, range: [0, 20] },
        edgePadding: { value: 8, range: [2, 20] },
        edgeGap: { value: 8, range: [0, 32] },
        cornerRadius: { value: 20, range: [0, 32] },
        backgroundOpacity: { value: 0.82, range: [0, 1], step: 0.01 },
        border: { value: true },
        borderWidth: { value: 0.5, range: [0.5, 4], step: 0.5 },
        borderColor: { value: "outline", choices: ["outline", "accent"] },
        borderOpacity: { value: 0.5, range: [0.1, 1], step: 0.05 },
        shadowGlowRadius: { value: 14, range: [0, 32], step: 0.5 },
        shadowSpread: { value: 0.08, range: [0, 0.5], step: 0.01 },
        // Fullscreen windows cover the Top layer: "hidden" leaves the Dock
        // under them, "reveal" lifts it above them on screen-edge hover.
        overFullscreen: { value: "hidden", choices: ["hidden", "reveal"] },
        revealStrip: { value: 3, range: [1, 12] }
    })

    property bool enabled: root.options.enabled.value
    property string position: root.options.position.value
    property string alignment: root.options.alignment.value
    property string focusedClick: root.options.focusedClick.value
    property string middleClick: root.options.middleClick.value
    property string runningScope: root.options.runningScope.value
    property bool launchBounce: root.options.launchBounce.value
    property bool showTooltips: root.options.showTooltips.value
    property int revealDuration: root.options.revealDuration.value
    property string autohide: root.options.autohide.value
    property int hideDelay: root.options.hideDelay.value
    property bool showRunning: root.options.showRunning.value
    property bool showRecents: root.options.showRecents.value
    property int recentCount: root.options.recentCount.value
    property bool scrollCycle: root.options.scrollCycle.value
    property string glass: root.options.glass.value
    readonly property bool glassActive: root.glass === "follow" ? Bridge.liquidGlassEnabled : root.glass === "on"
    property bool showIndicators: root.options.showIndicators.value
    property string indicatorStyle: root.options.indicatorStyle.value
    property bool showBadges: root.options.showBadges.value
    property bool showAppsButton: root.options.showAppsButton.value
    property bool showSettingsButton: root.options.showSettingsButton.value
    property bool showTrash: root.options.showTrash.value
    property bool previews: root.options.previews.value
    property bool magnify: root.options.magnify.value
    property real magnifyScale: root.options.magnifyScale.value
    property int iconSize: root.options.iconSize.value
    property int iconSpacing: root.options.iconSpacing.value
    property int edgePadding: root.options.edgePadding.value
    property int edgeGap: root.options.edgeGap.value
    property int cornerRadius: root.options.cornerRadius.value
    property real backgroundOpacity: root.options.backgroundOpacity.value
    property bool border: root.options.border.value
    property real borderWidth: root.options.borderWidth.value
    property string borderColor: root.options.borderColor.value
    property real borderOpacity: root.options.borderOpacity.value
    property real shadowGlowRadius: root.options.shadowGlowRadius.value
    property real shadowSpread: root.options.shadowSpread.value
    property string overFullscreen: root.options.overFullscreen.value
    property int revealStrip: root.options.revealStrip.value

    readonly property var windows: Hyprland.toplevels.values.map(top => root._window(top)).filter(window => window !== null)

    // Only changes when a window opens/closes/changes class or moves between
    // workspaces or monitors, so geometry refreshes don't rebuild icons.
    readonly property string _runningSignature: root.windows
        .map(window => [window.address, window.cls, window.workspaceId, window.monitorName].join("|")).join(",")

    // Rebuilt only when the signature, pins or entries change — not bound
    // to `windows`, which changes on every geometry/focus refresh and would
    // recreate every Dock icon (dropping hover, drag and launch state).
    // Window details that change without a rebuild (focus order) are read
    // fresh from `windows` where needed.
    property var items: []
    function _rebuildItems() {
        root.items = root._items(root.pins, root.windows, key => root.entryFor(key), cls => root._resolve(cls), root.showRunning,
            root.showRecents ? root.recents : [], root.recentCount);
        root._runningKeys = root.windows.map(window => {
            const entry = root._resolve(window.cls);
            return entry ? root.keyOf(entry) : "class:" + window.cls;
        });
        root._builtRecents = root._recentSignature;
    }
    function _scheduleRebuild() { Qt.callLater(root._rebuildItems); }
    on_RunningSignatureChanged: root._scheduleRebuild()
    onPinsChanged: root._scheduleRebuild()
    onShowRunningChanged: root._scheduleRebuild()

    // Focus changes reorder `recents` constantly; only rebuild when that
    // changes which recent apps are shown (or their order).
    property var _runningKeys: []
    property string _builtRecents: ""
    readonly property string _recentSignature: root.showRecents
        ? root._shownRecents(root.recents, root.pins.concat(root._runningKeys), root.recentCount, key => root.entryFor(key)).join(",") : ""
    on_RecentSignatureChanged: if (root._recentSignature !== root._builtRecents) root._scheduleRebuild()

    function noteRecent(key) {
        if (!key || key.startsWith("class:") || root.recents[0] === key) return;
        root.recents = [key].concat(root.recents.filter(recent => recent !== key)).slice(0, root._recentsKept);
        root._save();
    }

    // Notification badges: history entries for an app that arrived after
    // it was last activated or focused from anywhere.
    property var _seenAt: ({})
    readonly property var badges: root.showBadges ? root._badges(root.items, Notifications.state.history, root._seenAt) : ({})

    function badgeFor(key) { return root.badges[key] || 0; }
    function markSeen(key) {
        if (!key || !root.badges[key]) return;
        root._seenAt = Object.assign({}, root._seenAt, { [key]: Date.now() });
    }
    function _badges(items, history, seenAt) {
        const counts = {};
        for (const item of items) {
            if (item.separator) continue;
            const since = seenAt[item.key] || 0;
            const count = history.filter(record => record.time.getTime() > since && root._matches(item, record)).length;
            if (count > 0) counts[item.key] = count;
        }
        return counts;
    }
    function _matches(item, record) {
        const needles = [record.desktopEntry, record.appName].map(value => String(value || "").toLowerCase()).filter(value => value);
        const names = [item.key, item.name, item.entry ? item.entry.id : "", item.windows.length ? item.windows[0].cls : ""]
            .map(value => String(value || "").toLowerCase()).filter(value => value);
        return needles.some(needle => names.includes(needle));
    }

    function range(key) { return root.options[key].range; }
    function alignmentOffset(availableLength, contentLength) {
        const remaining = Math.max(0, availableLength - contentLength);
        return root.alignment === "start" ? 0 : root.alignment === "end" ? remaining : remaining / 2;
    }
    // Returns the stored value: clamped and stepped for numbers, ignored
    // (unchanged) for an unknown choice or a wrongly-typed value.
    function _coerce(key, value) {
        const option = root.options[key];
        if (!option || typeof value !== typeof option.value) return undefined;
        if (option.choices) return option.choices.includes(value) ? value : undefined;
        if (!option.range) return value;
        const step = option.step || 1;
        const clamped = Math.max(option.range[0], Math.min(option.range[1], value));
        return Number((Math.round(clamped / step) * step).toFixed(4));
    }
    function setOption(key, value) {
        const coerced = root._coerce(key, value);
        if (coerced === undefined) return;
        root[key] = coerced;
        // Debounced: a slider drag calls this every frame.
        root._saveTimer.restart();
    }
    function resetOptions() {
        for (const key in root.options) root[key] = root.options[key].value;
        root._save();
    }
    // Presets: every option above as JSON, copied and pasted through the
    // clipboard. Pins and screen choices stay per machine.
    function _preset() {
        const options = {};
        for (const key in root.options) options[key] = root[key];
        return JSON.stringify({ helios: "dock", version: 1, options: options }, null, 2);
    }
    // Returns how many settings were applied, or -1 when the text isn't a
    // Dock preset. Unknown keys and invalid values are skipped.
    function _applyPreset(text) {
        let preset;
        try { preset = JSON.parse(text); } catch (e) { return -1; }
        if (!preset || preset.helios !== "dock" || preset.version !== 1 || !preset.options
                || typeof preset.options !== "object" || Array.isArray(preset.options)) return -1;
        let applied = 0;
        for (const key in root.options) {
            if (!(key in preset.options)) continue;
            const coerced = root._coerce(key, preset.options[key]);
            if (coerced === undefined) continue;
            root[key] = coerced;
            applied++;
        }
        root._save();
        return applied;
    }
    // Short result note after a copy or paste; clears itself.
    property string presetStatus: ""
    onPresetStatusChanged: if (root.presetStatus) root._presetStatusClear.restart()
    property Timer _presetStatusClear: Timer { interval: 4000; onTriggered: root.presetStatus = "" }
    function copyPreset() {
        root._presetCopy.command = ["wl-copy", root._preset()];
        root._presetCopy.running = true;
        root.presetStatus = "Copied Dock settings";
    }
    function pastePreset() { root._presetPaste.running = true; }
    property Process _presetCopy: Process {}
    property Process _presetPaste: Process {
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                const applied = root._applyPreset(this.text);
                root.presetStatus = applied < 0 ? "Clipboard doesn't hold Dock settings"
                    : "Applied " + applied + " settings";
            }
        }
    }
    function shownOn(screenName) { return root.enabled && !root.hiddenScreens.includes(screenName); }
    function setShownOn(screenName, shown) {
        root.hiddenScreens = root.hiddenScreens.filter(name => name !== screenName).concat(shown ? [] : [screenName]);
        root._save();
    }
    function keyOf(entry) { return entry ? String(entry.id || entry.name || "") : ""; }
    // Separators are pins too, so they reorder and remove like apps.
    readonly property string separatorPrefix: "separator:"
    function isSeparator(key) { return String(key).startsWith(root.separatorPrefix); }
    // Inserts a separator at pin position index (default: the end).
    function addSeparator(index) {
        const ids = root.pins.filter(key => root.isSeparator(key)).map(key => parseInt(key.slice(root.separatorPrefix.length)) || 0);
        const key = root.separatorPrefix + (ids.length ? Math.max(...ids) + 1 : 1);
        root.placeAt(key, index === undefined ? root.pins.length : index);
    }
    function isPinned(key) { return root.pins.includes(key); }
    function pin(key) { if (key && !root.isPinned(key)) root._setPins(root.pins.concat([key])); }
    function unpin(key) { root._setPins(root.pins.filter(pinned => pinned !== key)); }
    // Moves (or pins) key to position index among the pins.
    function placeAt(key, index) {
        if (!key) return;
        const next = root.pins.filter(pinned => pinned !== key);
        next.splice(Math.max(0, Math.min(index, next.length)), 0, key);
        root._setPins(next);
    }
    function movePin(key, delta) {
        const index = root.pins.indexOf(key);
        if (index >= 0) root.placeAt(key, index + delta);
    }
    function _setPins(next) {
        root.pins = next;
        root._save();
    }
    property Timer _saveTimer: Timer {
        interval: 300
        onTriggered: root._save()
    }
    function _save() {
        const data = { pins: root.pins, hiddenScreens: root.hiddenScreens, recents: root.recents };
        for (const key in root.options) data[key] = root[key];
        settingsFile.setText(JSON.stringify(data));
    }

    readonly property string minimizedWorkspace: "special:minimized"

    // Trash: the directory is watched (not polled) so the icon shows
    // full/empty; only while the Trash button is shown.
    readonly property bool trashFull: root.showTrash && root._trashFiles.count > 0
    property FolderListModel _trashFiles: FolderListModel {
        folder: root.showTrash ? "file://" + (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/Trash/files" : ""
        showDirs: true
        showHidden: true
        showDotAndDotDot: false
    }
    function openTrash() { AppLaunch.exec(["gio", "open", "trash:///"]); }

    // Not running → launch. Minimized → restore. Running → focus its most
    // recent window; if the app already has focus, apply focusedClick.
    // Returns true when this launched the app.
    function activate(item) {
        if (!item) return false;
        root.markSeen(item.key);
        if (item.windows.length === 0) {
            if (!item.entry) return false;
            root.launchNew(item);
            return true;
        }
        const active = root._activeAddress();
        const fresh = new Map(root.windows.map(window => [window.address, window]));
        const ordered = item.windows.map(window => fresh.get(window.address) || window).sort((a, b) => a.focusHistoryId - b.focusHistoryId);
        const current = ordered.findIndex(window => window.address.replace(/^0x/, "") === active);
        const visible = ordered.filter(window => !root.isMinimized(window));
        if (visible.length === 0) {
            root.restore(item);
        } else if (current < 0 || root.isMinimized(ordered[current])) {
            AppLaunch.focusAddress(visible[0].address);
        } else if (root.focusedClick === "minimize") {
            root.minimize(item);
        } else if (root.focusedClick === "cycle" && visible.length > 1) {
            AppLaunch.focusAddress(visible[(visible.indexOf(ordered[current]) + 1) % visible.length].address);
        }
        return false;
    }
    function _activeAddress() {
        return Hyprland.activeToplevel ? String(Hyprland.activeToplevel.address || "").replace(/^0x/, "") : "";
    }
    // Focuses the next (step 1) or previous (step -1) visible window of
    // item, in the Dock's stable window order.
    function cycleWindows(item, step) {
        const visible = item ? item.windows.filter(window => !root.isMinimized(window)) : [];
        if (visible.length === 0) return;
        const active = root._activeAddress();
        const current = visible.findIndex(window => window.address.replace(/^0x/, "") === active);
        const next = current < 0 ? 0 : (current + step + visible.length) % visible.length;
        AppLaunch.focusAddress(visible[next].address);
    }
    function middleClickItem(item) {
        if (!item) return;
        if (root.middleClick === "close" && item.windows.length > 0) root.closeWindows(item);
        else root.launchNew(item);
    }
    function launchNew(item) {
        if (!item || !item.entry) return;
        Launcher.recordLaunch(item.entry.name);
        root.noteRecent(item.key);
        AppLaunch.launch(item.entry);
    }

    function isMinimized(window) { return window.workspaceName === root.minimizedWorkspace; }
    function minimize(item) {
        for (const window of item.windows)
            if (!root.isMinimized(window)) root._moveWindow(window.address, `"${root.minimizedWorkspace}"`);
    }
    // Brings minimized windows back to the focused monitor's workspace.
    function restore(item) {
        const monitor = Hyprland.focusedMonitor;
        const workspace = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0;
        const minimized = item.windows.filter(window => root.isMinimized(window));
        if (!workspace || minimized.length === 0) return;
        for (const window of minimized) root._moveWindow(window.address, workspace);
        AppLaunch.focusAddress(minimized[0].address);
    }
    // An empty address would make Hyprland act on the focused window, so
    // it is never dispatched.
    function _moveWindow(address, workspace) {
        const addr = String(address || "").replace(/^0x/, "");
        if (addr) Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspace}, window = "address:0x${addr}", follow = false })`);
    }

    // Items as one screen's Dock shows them: windows outside the running
    // scope are dropped, and unpinned apps left with none disappear.
    // Minimized windows always count, as they live on no screen.
    function scopedItems(items, screenName) {
        if (root.runningScope === "all") return items;
        const monitor = Hyprland.monitors.values.find(candidate => candidate.name === screenName);
        const workspaceId = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : null;
        return root._scope(items, root.runningScope, screenName, workspaceId);
    }
    function _scope(items, scope, screenName, workspaceId) {
        const inScope = window => root.isMinimized(window)
            || (scope === "monitor" ? window.monitorName === screenName : window.workspaceId === workspaceId);
        return items.map(item => Object.assign({}, item, { windows: item.windows.filter(inScope) }))
            .filter(item => item.pinned || item.recent || item.windows.length > 0);
    }

    function closeWindows(item) {
        if (!item) return;
        for (const window of item.windows) root.closeWindow(window.address);
    }
    function closeWindow(address) {
        const addr = String(address || "").replace(/^0x/, "");
        if (addr) Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${addr}" })`);
    }

    // True when a visible window on the screen's active workspace
    // intersects rect (global logical coordinates).
    function overlaps(screenName, rect) {
        const monitor = Hyprland.monitors.values.find(candidate => candidate.name === screenName);
        if (!monitor || !monitor.activeWorkspace) return false;
        return root._overlaps(root.windows, monitor.activeWorkspace.id, rect);
    }

    function _overlaps(windows, workspaceId, rect) {
        return windows.some(window => window.workspaceId === workspaceId && window.width > 0
            && window.x < rect.x + rect.width && window.x + window.width > rect.x
            && window.y < rect.y + rect.height && window.y + window.height > rect.y);
    }

    function _window(top) {
        const ipc = top.lastIpcObject || {};
        const cls = String(ipc["class"] || ipc.initialClass || "");
        if (!top.address || !cls) return null;
        const at = ipc.at || [0, 0];
        const size = ipc.size || [0, 0];
        return {
            address: "0x" + String(top.address).replace(/^0x/, ""),
            cls: cls,
            workspaceId: top.workspace ? top.workspace.id : (ipc.workspace ? ipc.workspace.id : -1),
            workspaceName: top.workspace ? String(top.workspace.name) : (ipc.workspace ? String(ipc.workspace.name) : ""),
            monitorName: top.monitor ? String(top.monitor.name) : "",
            x: at[0], y: at[1], width: size[0], height: size[1],
            focusHistoryId: ipc.focusHistoryID === undefined ? 0 : ipc.focusHistoryID,
            toplevel: top
        };
    }

    // Pinned items first (in pin order), then running apps not pinned, in
    // first-seen window order, then up to recentCount recent apps shown
    // nowhere else. Windows whose class resolves to no desktop entry still
    // get their own item, keyed by class.
    function _items(pins, windows, entryFor, resolve, showRunning, recents, recentCount) {
        const byKey = {};
        const running = [];
        for (const window of windows) {
            const entry = resolve(window.cls);
            const key = entry ? root.keyOf(entry) : "class:" + window.cls;
            if (!byKey[key]) {
                byKey[key] = { key: key, entry: entry, name: entry ? entry.name : window.cls, icon: entry ? entry.icon : window.cls, windows: [], pinned: false };
                running.push(key);
            }
            byKey[key].windows.push(window);
        }
        const items = [];
        for (const key of pins) {
            if (root.isSeparator(key)) {
                items.push({ key: key, entry: null, name: "", icon: "", windows: [], pinned: true, separator: true });
                continue;
            }
            const entry = byKey[key] ? byKey[key].entry : entryFor(key);
            if (!entry && !byKey[key]) continue;
            items.push(Object.assign(byKey[key] || { key: key, entry: entry, name: entry.name, icon: entry.icon, windows: [] }, { pinned: true }));
        }
        if (showRunning !== false)
            items.push(...running.filter(key => !pins.includes(key)).map(key => byKey[key]));
        const recentKeys = root._shownRecents(recents || [], pins.concat(running), recentCount, entryFor);
        return items.concat(recentKeys.map(key => {
            const entry = entryFor(key);
            return { key: key, entry: entry, name: entry.name, icon: entry.icon, windows: [], pinned: false, recent: true };
        }));
    }
    function _shownRecents(recents, shownKeys, count, entryFor) {
        return recents.filter(key => !shownKeys.includes(key) && entryFor(key)).slice(0, count);
    }

    function entryFor(key) {
        return Launcher.applications.find(entry => root.keyOf(entry) === key) || null;
    }

    // heuristicLookup per class is cached; desktop entries rarely change.
    property var _resolveCache: ({})
    function _resolve(cls) {
        if (!(cls in root._resolveCache)) root._resolveCache[cls] = AppLaunch.resolveEntry(cls, "");
        return root._resolveCache[cls];
    }

    // Focusing an app from anywhere (keyboard, Launcher) clears its badge.
    property Connections _focusChanges: Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const active = Hyprland.activeToplevel;
            const item = active ? root.items.find(candidate => candidate.windows.some(window => window.toplevel === active)) : null;
            if (item) {
                root.markSeen(item.key);
                if (item.entry) root.noteRecent(item.key);
            }
        }
    }

    property Connections _entryChanges: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root._resolveCache = ({});
            root._scheduleRebuild();
        }
    }

    // lastIpcObject (geometry, focus history) only updates on refresh.
    property Timer _refreshDebounce: Timer {
        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }
    readonly property var _refreshEvents: ["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen",
        "workspacev2", "focusedmonv2", "activewindowv2", "resizewindow", "movewindow"]
    property Connections _hyprlandEvents: Connections {
        target: Hyprland
        function onRawEvent(event) { if (root._refreshEvents.includes(event.name)) root._refreshDebounce.restart(); }
    }
    property Connections _extraAppChanges: Connections {
        target: ExtraApps
        function onListChanged() { root._scheduleRebuild(); }
    }
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        root._rebuildItems();
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("dock.json")
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(settingsFile.text());
                if (Array.isArray(parsed.pins)) root.pins = parsed.pins.map(String);
                if (Array.isArray(parsed.hiddenScreens)) root.hiddenScreens = parsed.hiddenScreens.map(String);
                if (Array.isArray(parsed.recents)) root.recents = parsed.recents.map(String).slice(0, root._recentsKept);
                for (const key in root.options) {
                    const value = root._coerce(key, parsed[key]);
                    if (value !== undefined) root[key] = value;
                }
            } catch (error) {}
        }
    }
}
