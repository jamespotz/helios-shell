pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Apple uses SF Pro — on Linux, Inter is the closest match with its
    // tight metrics, open apertures, and tabular figures. JetBrains Mono
    // for monospace (geometric, clear at small sizes like SF Mono). Body
    // font is user-tunable from Settings > Appearance; icon/mono fonts
    // stay fixed since Material Symbols relies on ligatures.
    readonly property string fontFamily: settingsAdapter.fontFamily
    readonly property string monoFontFamily: "JetBrains Mono"
    readonly property string iconFontFamily: "Material Symbols Rounded"

    readonly property string terminal: "ghostty"
    readonly property string pamService: "system-auth"

    // Apple HIG uses ~250ms for standard transitions, 350ms for larger
    // surface changes — slightly slower than before for a calmer feel.
    readonly property int animFast: 160
    readonly property int animMedium: 280
    // Theme crossfade duration — Colors.qml's own ColorAnimation Behaviors
    // reference this so there's one source of truth for animation timing
    // instead of two singletons independently claiming to own it.
    readonly property int animSlow: 380

    // Dynamic island — Apple-style: slightly taller idle bump for better
    // readability, more breathing room from the screen edge. These are the
    // shipped defaults; user-tunable from Settings > Island.
    readonly property int fontSize: settingsAdapter.fontSize
    readonly property int idleBumpWidth: settingsAdapter.idleBumpWidth
    readonly property int idleBumpHeight: settingsAdapter.idleBumpHeight
    readonly property int islandTopGap: settingsAdapter.islandTopGap
    // Spacing between widgets in the collapsed idle bump — user-tunable
    // from Settings > Island.
    readonly property int idleWidgetSpacing: settingsAdapter.idleWidgetSpacing
    // Padding around the expanded/peek island's content — user-tunable
    // from Settings > Island. Idle mode still forces 0
    // (see Bar.qml), only expanded/peek content uses these.
    readonly property int islandContentPadH: settingsAdapter.islandContentPadH
    readonly property int islandContentPadV: settingsAdapter.islandContentPadV

    // exclusiveZone: how much top space Hyprland reserves for *every* window
    // below, so a maximized window's title bar never sits flush against the
    // idle bump. Deliberately just enough to clear the bump itself (top gap
    // + bump height) with no extra padding of our own: Hyprland's general
    // gap settings (gaps_out, etc.) already add further space on top of this
    // reservation when it places a window, so any additional margin we added
    // here stacked on top of that and made the visible gap under the bump
    // noticeably bigger than the gap above it, which is a plain, untouched
    // `margins.top` unaffected by Hyprland's own window-gap logic. This is a
    // flat constant regardless of mode (see Bar.qml) — expanded states
    // overlap windows rather than growing the reservation, so the gap stays
    // put whether the island is idle or expanded.
    readonly property int islandExclusiveZone: islandTopGap + idleBumpHeight
    // Apple's peek/hover state is slightly taller for better touch/click
    // targets and more breathing room around text.
    readonly property int peekHeight: settingsAdapter.peekHeight
    readonly property int mediaWidth: 360
    // Width of every alert card the island shows (notification, task,
    // meeting, battery) and how long a notification stays before it
    // dismisses itself — user-tunable from Settings > Island.
    readonly property int notifyWidth: settingsAdapter.notifyWidth
    readonly property int notifyDuration: settingsAdapter.notifyDuration

    // The island's real layer-shell surface stays this size the whole time —
    // only an inner item animates (see Bar.qml) — so the morph is plain GPU
    // compositing instead of a real Wayland resize every frame. Must comfortably
    // fit the widest/tallest panel content plus padding, including whatever
    // idleBumpWidth/Height the user dials in above. Sized with real slack
    // beyond typical content (rather than a tight fit) since a long focused-
    // window title (ActiveWindow.qml) can push the idle/peek row wider than
    // usual — the surface is transparent and click-through outside the
    // visible pill (see Bar.qml's `mask`), so extra headroom here is free.
    readonly property int islandMaxWidth: 1300
    readonly property int islandMaxHeight: 820

    // Apple-style spring: critically damped (no overshoot) with moderate
    // stiffness for a smooth, decisive morph. Both axes must share params
    // or they desync mid-animation. User-tunable from Settings >
    // Island.
    readonly property real islandSpringStiffness: settingsAdapter.islandSpringStiffness
    readonly property real islandSpringDamping: settingsAdapter.islandSpringDamping

    // Motion presets set the island and satellite springs together. The
    // active preset is derived from those four values rather than stored,
    // so moving an Advanced slider reads as "custom".
    readonly property var motionPresets: ({
        snappy: { stiffness: 7.0, damping: 1.0 },
        smooth: { stiffness: 4.0, damping: 1.0 },
        bouncy: { stiffness: 4.0, damping: 0.4 }
    })
    readonly property var motionKeys: ["islandSpringStiffness", "islandSpringDamping", "satelliteSpringStiffness", "satelliteSpringDamping"]
    readonly property string motionPreset: {
        for (const name in root.motionPresets) {
            const p = root.motionPresets[name];
            if (islandSpringStiffness === p.stiffness && islandSpringDamping === p.damping
                    && satelliteSpringStiffness === p.stiffness && satelliteSpringDamping === p.damping)
                return name;
        }
        return "custom";
    }

    function applyMotionPreset(name) {
        const p = root.motionPresets[name];
        if (!p) return;
        root.setOption("islandSpringStiffness", p.stiffness);
        root.setOption("islandSpringDamping", p.damping);
        root.setOption("satelliteSpringStiffness", p.stiffness);
        root.setOption("satelliteSpringDamping", p.damping);
    }

    // How long the island stays expanded after the cursor leaves before it
    // collapses back to the idle bump — user-tunable from Settings >
    // Island.
    readonly property int hoverCollapseDelay: settingsAdapter.hoverCollapseDelay
    // Whether hovering the idle bump opens the peek row, and how long the
    // pointer has to rest there first. With hover off, clicking the idle
    // bump opens it instead (see Bar.qml).
    readonly property bool hoverExpand: settingsAdapter.hoverExpand
    readonly property int hoverExpandDelay: settingsAdapter.hoverExpandDelay

    // What the idle pill does with the wheel, middle click and right click
    // (see IslandGestures), and whether alerts and shortcut-opened panels
    // rise above a fullscreen window — user-tunable from Settings > Island.
    readonly property string gestureScroll: settingsAdapter.gestureScroll
    readonly property string gestureMiddleClick: settingsAdapter.gestureMiddleClick
    readonly property string gestureRightClick: settingsAdapter.gestureRightClick
    readonly property string islandOverFullscreen: settingsAdapter.islandOverFullscreen

    // Which alert cards may take over the island, the Bluetooth low-battery
    // threshold, whether critical notifications wait to be dismissed, and
    // alert sounds — user-tunable from Settings > Island > Alerts.
    readonly property bool showTaskAlerts: settingsAdapter.showTaskAlerts
    readonly property bool showMeetingAlerts: settingsAdapter.showMeetingAlerts
    readonly property bool showBatteryAlerts: settingsAdapter.showBatteryAlerts
    readonly property int batteryAlertThreshold: settingsAdapter.batteryAlertThreshold
    readonly property bool keepCriticalAlerts: settingsAdapter.keepCriticalAlerts
    readonly property bool alertSounds: settingsAdapter.alertSounds

    // Screen names the island is turned off on. An island panel opened on
    // one of them (keybind/IPC) still shows until it closes.
    readonly property var islandHiddenScreens: settingsAdapter.islandHiddenScreens

    // Falls back to every screen if all connected ones are hidden (e.g. the
    // only shown monitor was unplugged), so alerts always have somewhere to go.
    function islandShownOn(screenName) {
        const hidden = root.islandHiddenScreens;
        return !hidden.includes(screenName) || Quickshell.screens.every(s => hidden.includes(s.name));
    }

    // Which screens show alert cards: "all", "focused", or a screen name —
    // see IslandNavigation._alertsOn. Set from Settings > Island > Screens.
    readonly property string alertScreen: settingsAdapter.alertScreen

    // Island destinations left out of Launcher search. Shortcuts, status
    // icons and IPC still open them. Set from Settings > Island > Launcher.
    readonly property var hiddenDestinations: settingsAdapter.hiddenDestinations
    function destinationHidden(id) { return root.hiddenDestinations.includes(id); }
    function setDestinationHidden(id, hidden) {
        const rest = root.hiddenDestinations.filter(d => d !== id);
        settingsAdapter.hiddenDestinations = hidden ? rest.concat([id]) : rest;
        root._save();
    }

    function setIslandShownOn(screenName, shown) {
        settingsAdapter.islandHiddenScreens = root.islandHiddenScreens.filter(name => name !== screenName)
            .concat(shown ? [] : [screenName]);
        root._save();
    }

    // Idle and expanded share one IslandShape instance (it morphs between
    // sizes rather than swapping shapes), so its shadow is one shared knob
    // rather than per-mode — user-tunable from Settings > Island. Satellites use their own separate shadow values below.
    readonly property real islandShadowGlowRadius: settingsAdapter.islandShadowGlowRadius
    readonly property real islandShadowSpread: settingsAdapter.islandShadowSpread

    // Satellite badges (recording/maintenance) — visually and motion-wise
    // independent from the main island; user-tunable from Settings >
    // Island.
    readonly property int satelliteBadgeSize: settingsAdapter.satelliteBadgeSize
    readonly property int satelliteRestGap: settingsAdapter.satelliteRestGap
    readonly property int satellitePadH: settingsAdapter.satellitePadH
    readonly property int satellitePadV: settingsAdapter.satellitePadV
    readonly property real satelliteShadowGlowRadius: settingsAdapter.satelliteShadowGlowRadius
    readonly property real satelliteShadowSpread: settingsAdapter.satelliteShadowSpread
    readonly property real satelliteSpringStiffness: settingsAdapter.satelliteSpringStiffness
    readonly property real satelliteSpringDamping: settingsAdapter.satelliteSpringDamping

    // Which widgets the expanded/peek island shows — user-tunable from the
    // "Island" settings tab's Widgets section. Keyed by settingsAdapter
    // property name so the settings UI can drive them generically.
    readonly property bool showWorkspaces: settingsAdapter.showWorkspaces
    readonly property bool showTiledLayout: settingsAdapter.showTiledLayout
    readonly property bool showActiveWindow: settingsAdapter.showActiveWindow
    readonly property bool showClock: settingsAdapter.showClock
    readonly property bool showWeather: settingsAdapter.showWeather
    readonly property bool showTray: settingsAdapter.showTray
    readonly property bool showStatusIndicators: settingsAdapter.showStatusIndicators
    readonly property bool showClipboard: settingsAdapter.showClipboard
    readonly property bool showLauncher: settingsAdapter.showLauncher
    readonly property bool showIdleLauncher: settingsAdapter.showIdleLauncher
    readonly property string launcherIconMode: settingsAdapter.launcherIconMode
    readonly property string launcherIconPath: settingsAdapter.launcherIconPath

    // Same idea, but for the collapsed idle bump — the small pill shown when
    // nothing else is active, before it morphs open into the peek/expanded
    // island.
    readonly property bool showIdleMedia: settingsAdapter.showIdleMedia
    readonly property bool showIdleClock: settingsAdapter.showIdleClock
    readonly property bool showIdleWeather: settingsAdapter.showIdleWeather
    readonly property bool showIdleTiledLayout: settingsAdapter.showIdleTiledLayout
    // Off by default — these are the bulkier expanded-island widgets, opt-in
    // for anyone who wants a fuller idle bump instead of the minimal one.
    readonly property bool showIdleWorkspaces: settingsAdapter.showIdleWorkspaces
    readonly property bool showIdleActiveWindow: settingsAdapter.showIdleActiveWindow
    readonly property bool showIdleTray: settingsAdapter.showIdleTray
    readonly property bool showIdleStatusIndicators: settingsAdapter.showIdleStatusIndicators
    readonly property bool showIdleClipboard: settingsAdapter.showIdleClipboard

    // Widget order and side for the idle pill and the hover row. Each list
    // holds every widget key once plus one "|" marker: keys before it sit
    // on the left, after it on the right. Whether a widget shows is still
    // its show*/showIdle* toggle above. Set from Settings > Island.
    readonly property var widgetKeys: ({
        idle: ["workspaces", "tiledLayout", "activeWindow", "media", "clock", "weather", "tray", "clipboard", "statusIndicators", "launcher"],
        peek: ["workspaces", "tiledLayout", "activeWindow", "clock", "weather", "tray", "clipboard", "statusIndicators", "launcher"]
    })
    readonly property var idleWidgetLayout: root._sanitizeLayout("idle", settingsAdapter.idleLayout)
    readonly property var peekWidgetLayout: root._sanitizeLayout("peek", settingsAdapter.peekLayout)

    function layoutFor(surface) { return surface === "idle" ? root.idleWidgetLayout : root.peekWidgetLayout; }

    // The show*/showIdle* option that toggles a widget key.
    function widgetOption(surface, key) {
        return (surface === "idle" ? "showIdle" : "show") + key.charAt(0).toUpperCase() + key.slice(1);
    }

    function widgetShown(surface, key) {
        return key === "|" || !!root[root.widgetOption(surface, key)];
    }

    // Drops unknown and repeated keys, appends missing ones at the end, and
    // keeps exactly one marker (last, when it was missing).
    function _sanitizeLayout(surface, stored) {
        const known = root.widgetKeys[surface];
        const source = Array.isArray(stored) ? stored : root.options[surface + "Layout"].value;
        const out = [];
        for (const key of source)
            if ((key === "|" || known.includes(key)) && !out.includes(key)) out.push(key);
        const missing = known.filter(key => !out.includes(key));
        const marker = out.indexOf("|");
        if (marker < 0) return out.concat(missing, ["|"]);
        return out.concat(missing);
    }

    function moveWidget(surface, key, index) {
        const layout = root.layoutFor(surface).filter(k => k !== key);
        if (layout.length === root.layoutFor(surface).length) return;
        layout.splice(Math.max(0, Math.min(index, layout.length)), 0, key);
        settingsAdapter[surface + "Layout"] = layout;
        root._save();
    }

    // Workspace indicator look — "dots" (pill for the focused workspace),
    // "numbers" (Material Symbols counter_N glyphs), or "custom" (a
    // user-picked Material Symbol per workspace, counter_N when unset).
    // Set from Settings > Workspaces.
    readonly property string workspaceIndicatorStyle: settingsAdapter.workspaceIndicatorStyle
    // Workspace id (as a string key) → Material Symbol name.
    readonly property var workspaceIcons: settingsAdapter.workspaceIcons
    // false = only the monitor's active workspace is shown.
    readonly property bool showAllWorkspaces: settingsAdapter.showAllWorkspaces

    // Empty icon clears the override. Reassigns a copy so bindings update.
    function setWorkspaceIcon(id, icon) {
        const icons = Object.assign({}, settingsAdapter.workspaceIcons);
        if (icon)
            icons[id] = icon;
        else
            delete icons[id];
        settingsAdapter.workspaceIcons = icons;
        root._save();
    }

    // Clock format — user-tunable from Settings > Date &
    // time. clockAmPmUppercase only matters in 12-hour mode; every clock
    // in the shell (Clock, IdleBump, WeatherPanel, Lock) reads timeFormat
    // rather than each hardcoding its own format string, so they always
    // agree with each other and with this setting.
    readonly property bool use24HourClock: settingsAdapter.use24HourClock
    readonly property bool clockAmPmUppercase: settingsAdapter.clockAmPmUppercase
    readonly property string timeFormat: root.use24HourClock ? "HH:mm"
        : root.clockAmPmUppercase ? "h:mm AP" : "h:mm ap"

    // Settings window respects this for its open/close and page-switch
    // transitions — user-tunable from Settings > Appearance.
    readonly property bool reducedMotion: settingsAdapter.reducedMotion

    // Transition awww plays when the wallpaper changes (its own
    // --transition-type values — see WallpaperPlayback.qml.
    readonly property string wallpaperTransitionStyle: settingsAdapter.wallpaperTransitionStyle
    readonly property var wallpaperTransitionStyles: ["simple", "center", "outer", "left", "right", "top", "bottom", "any", "random"]

    // Every user option in island-appearance.json (workspaceIcons and
    // islandHiddenScreens aside):
    // default, plus [min, max] (and step) for numbers or the allowed values
    // for choices. setOption() clamps/validates against this, and the
    // adapter below takes its defaults from it — same shape as Dock.options.
    readonly property var options: ({
        fontFamily: { value: "Inter" },
        fontSize: { value: 13, range: [9, 22] },

        idleBumpWidth: { value: 140, range: [80, 400] },
        idleBumpHeight: { value: 32, range: [18, 60] },
        islandTopGap: { value: 10, range: [0, 40] },
        idleWidgetSpacing: { value: 8, range: [0, 40] },
        islandContentPadH: { value: 18, range: [0, 60] },
        islandContentPadV: { value: 10, range: [0, 40] },
        peekHeight: { value: 44, range: [32, 72] },
        notifyWidth: { value: 380, range: [300, 600] },
        notifyDuration: { value: 5000, range: [1000, 30000], step: 500 },
        showTaskAlerts: { value: true },
        showMeetingAlerts: { value: true },
        showBatteryAlerts: { value: true },
        batteryAlertThreshold: { value: 20, range: [5, 50], step: 5 },
        keepCriticalAlerts: { value: true },
        alertSounds: { value: false },

        showWorkspaces: { value: true },
        showTiledLayout: { value: false },
        showActiveWindow: { value: true },
        showClock: { value: true },
        showWeather: { value: true },
        showTray: { value: true },
        showStatusIndicators: { value: true },
        showClipboard: { value: false },
        showLauncher: { value: false },
        showIdleLauncher: { value: false },
        launcherIconMode: { value: "os", choices: ["os", "custom"] },
        launcherIconPath: { value: "" },

        showIdleMedia: { value: true },
        showIdleClock: { value: true },
        showIdleWeather: { value: true },
        showIdleTiledLayout: { value: false },
        showIdleWorkspaces: { value: false },
        showIdleActiveWindow: { value: false },
        showIdleTray: { value: false },
        showIdleStatusIndicators: { value: false },
        showIdleClipboard: { value: false },
        idleLayout: { value: ["workspaces", "tiledLayout", "activeWindow", "media", "clock", "weather", "tray", "clipboard", "statusIndicators", "|"] },
        peekLayout: { value: ["workspaces", "tiledLayout", "activeWindow", "|", "clock", "weather", "tray", "clipboard", "statusIndicators"] },

        workspaceIndicatorStyle: { value: "dots", choices: ["dots", "numbers", "custom"] },
        showAllWorkspaces: { value: true },

        wallpaperTransitionStyle: { value: "any", choices: root.wallpaperTransitionStyles },

        use24HourClock: { value: false },
        clockAmPmUppercase: { value: true },

        reducedMotion: { value: false },

        // Spring minimums stay above 0: a zero stiffness never moves and
        // zero damping never settles.
        hoverCollapseDelay: { value: 260, range: [0, 2000], step: 10 },
        hoverExpand: { value: true },
        hoverExpandDelay: { value: 80, range: [0, 1000], step: 10 },
        gestureScroll: { value: "volume", choices: ["off", "volume", "workspace"] },
        gestureMiddleClick: { value: "playpause", choices: ["off", "playpause", "mute"] },
        gestureRightClick: { value: "off", choices: ["off", "launcher", "notifications", "media", "calendar", "volume"] },
        islandOverFullscreen: { value: "hidden", choices: ["hidden", "alerts"] },
        hiddenDestinations: { value: [] },
        alertScreen: { value: "all" },
        islandSpringStiffness: { value: 4.0, range: [0.5, 12], step: 0.1 },
        islandSpringDamping: { value: 1.0, range: [0.1, 8], step: 0.1 },
        islandShadowGlowRadius: { value: 14, range: [0, 32], step: 0.5 },
        islandShadowSpread: { value: 0.08, range: [0, 0.5], step: 0.01 },

        satelliteBadgeSize: { value: 32, range: [20, 60] },
        satelliteRestGap: { value: 10, range: [0, 24] },
        satellitePadH: { value: 10, range: [0, 40] },
        satellitePadV: { value: 10, range: [0, 40] },
        satelliteShadowGlowRadius: { value: 5, range: [0, 20], step: 0.5 },
        satelliteShadowSpread: { value: 0, range: [0, 0.5], step: 0.01 },
        satelliteSpringStiffness: { value: 4.0, range: [0.5, 12], step: 0.1 },
        satelliteSpringDamping: { value: 1.0, range: [0.1, 8], step: 0.1 }
    })

    function range(key) { return root.options[key].range; }

    // Returns the stored value: clamped and stepped for numbers, undefined
    // for an unknown key, an unknown choice, or a wrongly-typed value.
    function _coerce(key, value) {
        const option = root.options[key];
        if (!option || typeof value !== typeof option.value) return undefined;
        if (Array.isArray(option.value) !== Array.isArray(value)) return undefined;
        if (option.choices) return option.choices.includes(value) ? value : undefined;
        if (!option.range) return value;
        const step = option.step || 1;
        const clamped = Math.max(option.range[0], Math.min(option.range[1], value));
        return Number((Math.round(clamped / step) * step).toFixed(4));
    }

    // Applies immediately; the file write is debounced so dragging a
    // slider doesn't rewrite the JSON every frame.
    function setOption(key, value) {
        const coerced = root._coerce(key, value);
        if (coerced === undefined) return;
        settingsAdapter[key] = coerced;
        root._save();
    }

    // Island presets: every option on Settings > Island (everything here but
    // the global font, clock, workspace, wallpaper and motion options) as
    // JSON, copied and pasted through the clipboard.
    readonly property var islandKeys: Object.keys(root.options).filter(key => ![
        "fontFamily", "fontSize", "workspaceIndicatorStyle", "showAllWorkspaces",
        "wallpaperTransitionStyle", "use24HourClock", "clockAmPmUppercase", "reducedMotion"
    ].includes(key))

    function _islandPreset() {
        const options = {};
        for (const key of root.islandKeys) options[key] = settingsAdapter[key];
        return JSON.stringify({ helios: "island", version: 1, options: options }, null, 2);
    }

    // Returns how many settings were applied, or -1 when the text isn't an
    // Island preset. Unknown keys and invalid values are skipped.
    function _applyIslandPreset(text) {
        let preset;
        try { preset = JSON.parse(text); } catch (e) { return -1; }
        if (!preset || preset.helios !== "island" || preset.version !== 1 || !preset.options
                || typeof preset.options !== "object" || Array.isArray(preset.options)) return -1;
        let applied = 0;
        for (const key of root.islandKeys) {
            if (!(key in preset.options)) continue;
            const coerced = root._coerce(key, preset.options[key]);
            if (coerced === undefined) continue;
            settingsAdapter[key] = coerced;
            applied++;
        }
        root._save();
        return applied;
    }

    // Short result note after a copy or paste; clears itself.
    property string presetStatus: ""
    onPresetStatusChanged: if (root.presetStatus) root._presetStatusClear.restart()
    property Timer _presetStatusClear: Timer { interval: 4000; onTriggered: root.presetStatus = "" }

    function copyIslandPreset() {
        root._presetCopy.command = ["wl-copy", root._islandPreset()];
        root._presetCopy.running = true;
        root.presetStatus = "Copied Island settings";
    }

    function pasteIslandPreset() { root._presetPaste.running = true; }

    property Process _presetCopy: Process {}
    property Process _presetPaste: Process {
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                const applied = root._applyIslandPreset(this.text);
                root.presetStatus = applied < 0 ? "Clipboard doesn't hold Island settings"
                    : "Applied " + applied + " settings";
            }
        }
    }

    function resetOptions(keys) {
        for (const key of keys) settingsAdapter[key] = root.options[key].value;
        root._save();
    }

    function _save() { root._saveTimer.restart(); }

    property Timer _saveTimer: Timer {
        interval: 300
        onTriggered: root.settingsFile.writeAdapter()
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("island-appearance.json")
        watchChanges: true
        // Pick up hand edits to the JSON live, not just on next launch.
        onFileChanged: reload()

        JsonAdapter {
            id: settingsAdapter
            property string fontFamily: root.options.fontFamily.value
            property int fontSize: root.options.fontSize.value
            property int idleBumpWidth: root.options.idleBumpWidth.value
            property int idleBumpHeight: root.options.idleBumpHeight.value
            property int islandTopGap: root.options.islandTopGap.value
            property int idleWidgetSpacing: root.options.idleWidgetSpacing.value
            property int islandContentPadH: root.options.islandContentPadH.value
            property int islandContentPadV: root.options.islandContentPadV.value
            property int peekHeight: root.options.peekHeight.value
            property int notifyWidth: root.options.notifyWidth.value
            property int notifyDuration: root.options.notifyDuration.value
            property bool showWorkspaces: root.options.showWorkspaces.value
            property bool showTiledLayout: root.options.showTiledLayout.value
            property bool showActiveWindow: root.options.showActiveWindow.value
            property bool showClock: root.options.showClock.value
            property bool showWeather: root.options.showWeather.value
            property bool showTray: root.options.showTray.value
            property bool showStatusIndicators: root.options.showStatusIndicators.value
            property bool showClipboard: root.options.showClipboard.value
            property bool showLauncher: root.options.showLauncher.value
            property bool showIdleLauncher: root.options.showIdleLauncher.value
            property string launcherIconMode: root.options.launcherIconMode.value
            property string launcherIconPath: root.options.launcherIconPath.value
            property bool showIdleMedia: root.options.showIdleMedia.value
            property bool showIdleClock: root.options.showIdleClock.value
            property bool showIdleWeather: root.options.showIdleWeather.value
            property bool showIdleTiledLayout: root.options.showIdleTiledLayout.value
            property bool showIdleWorkspaces: root.options.showIdleWorkspaces.value
            property bool showIdleActiveWindow: root.options.showIdleActiveWindow.value
            property bool showIdleTray: root.options.showIdleTray.value
            property bool showIdleStatusIndicators: root.options.showIdleStatusIndicators.value
            property bool showIdleClipboard: root.options.showIdleClipboard.value
            property var idleLayout: root.options.idleLayout.value
            property var peekLayout: root.options.peekLayout.value
            property string workspaceIndicatorStyle: root.options.workspaceIndicatorStyle.value
            property bool showAllWorkspaces: root.options.showAllWorkspaces.value
            property var workspaceIcons: ({})
            property string wallpaperTransitionStyle: root.options.wallpaperTransitionStyle.value
            property bool use24HourClock: root.options.use24HourClock.value
            property bool clockAmPmUppercase: root.options.clockAmPmUppercase.value
            property bool reducedMotion: root.options.reducedMotion.value
            property int hoverCollapseDelay: root.options.hoverCollapseDelay.value
            property bool hoverExpand: root.options.hoverExpand.value
            property int hoverExpandDelay: root.options.hoverExpandDelay.value
            property string gestureScroll: root.options.gestureScroll.value
            property string gestureMiddleClick: root.options.gestureMiddleClick.value
            property string gestureRightClick: root.options.gestureRightClick.value
            property string islandOverFullscreen: root.options.islandOverFullscreen.value
            property var hiddenDestinations: root.options.hiddenDestinations.value
            property string alertScreen: root.options.alertScreen.value
            property bool showTaskAlerts: root.options.showTaskAlerts.value
            property bool showMeetingAlerts: root.options.showMeetingAlerts.value
            property bool showBatteryAlerts: root.options.showBatteryAlerts.value
            property int batteryAlertThreshold: root.options.batteryAlertThreshold.value
            property bool keepCriticalAlerts: root.options.keepCriticalAlerts.value
            property bool alertSounds: root.options.alertSounds.value
            property var islandHiddenScreens: []
            property real islandSpringStiffness: root.options.islandSpringStiffness.value
            property real islandSpringDamping: root.options.islandSpringDamping.value
            property real islandShadowGlowRadius: root.options.islandShadowGlowRadius.value
            property real islandShadowSpread: root.options.islandShadowSpread.value
            property int satelliteBadgeSize: root.options.satelliteBadgeSize.value
            property int satelliteRestGap: root.options.satelliteRestGap.value
            property int satellitePadH: root.options.satellitePadH.value
            property int satellitePadV: root.options.satellitePadV.value
            property real satelliteShadowGlowRadius: root.options.satelliteShadowGlowRadius.value
            property real satelliteShadowSpread: root.options.satelliteShadowSpread.value
            property real satelliteSpringStiffness: root.options.satelliteSpringStiffness.value
            property real satelliteSpringDamping: root.options.satelliteSpringDamping.value
        }
    }
}
