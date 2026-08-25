pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Apple uses SF Pro — on Linux, Inter is the closest match with its
    // tight metrics, open apertures, and tabular figures. JetBrains Mono
    // for monospace (geometric, clear at small sizes like SF Mono).
    readonly property string fontFamily: "Inter"
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
    // shipped defaults; user-tunable from IslandSettings.
    readonly property int fontSize: settingsAdapter.fontSize
    readonly property int idleBumpWidth: settingsAdapter.idleBumpWidth
    readonly property int idleBumpHeight: settingsAdapter.idleBumpHeight
    readonly property int islandTopGap: settingsAdapter.islandTopGap

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
    readonly property int peekHeight: 44
    readonly property int mediaWidth: 360
    readonly property int notifyWidth: 380

    // The island's real layer-shell surface stays this size the whole time —
    // only an inner item animates (see Bar.qml) — so the morph is plain GPU
    // compositing instead of a real Wayland resize every frame. Must comfortably
    // fit the widest/tallest panel content plus padding, including whatever
    // idleBumpWidth/Height the user dials in above.
    readonly property int islandMaxWidth: 1000
    readonly property int islandMaxHeight: 480

    // Apple-style spring: critically damped (no overshoot) with moderate
    // stiffness for a smooth, decisive morph. Both axes must share params
    // or they desync mid-animation.
    readonly property real islandSpringStiffness: 4.0
    readonly property real islandSpringDamping: 1.0

    function setIslandAppearance(width, height, gap, size) {
        settingsAdapter.idleBumpWidth = width;
        settingsAdapter.idleBumpHeight = height;
        settingsAdapter.islandTopGap = gap;
        settingsAdapter.fontSize = size;
        root.settingsFile.writeAdapter();
    }

    function resetIslandAppearance() {
        root.setIslandAppearance(140, 32, 10, 13);
    }

    // Which widgets the expanded/peek island shows — user-tunable from the
    // "Island" settings tab's Widgets section. Keyed by settingsAdapter
    // property name so the settings UI can drive them generically.
    readonly property bool showWorkspaces: settingsAdapter.showWorkspaces
    readonly property bool showActiveWindow: settingsAdapter.showActiveWindow
    readonly property bool showClock: settingsAdapter.showClock
    readonly property bool showWeather: settingsAdapter.showWeather
    readonly property bool showTray: settingsAdapter.showTray
    readonly property bool showStatusIndicators: settingsAdapter.showStatusIndicators
    readonly property bool showClipboard: settingsAdapter.showClipboard

    // Same idea, but for the collapsed idle bump — the small pill shown when
    // nothing else is active, before it morphs open into the peek/expanded
    // island.
    readonly property bool showIdleMedia: settingsAdapter.showIdleMedia
    readonly property bool showIdleClock: settingsAdapter.showIdleClock
    readonly property bool showIdleWeather: settingsAdapter.showIdleWeather
    // Off by default — these are the bulkier expanded-island widgets, opt-in
    // for anyone who wants a fuller idle bump instead of the minimal one.
    readonly property bool showIdleWorkspaces: settingsAdapter.showIdleWorkspaces
    readonly property bool showIdleActiveWindow: settingsAdapter.showIdleActiveWindow
    readonly property bool showIdleTray: settingsAdapter.showIdleTray
    readonly property bool showIdleStatusIndicators: settingsAdapter.showIdleStatusIndicators
    readonly property bool showIdleClipboard: settingsAdapter.showIdleClipboard

    function setWidgetVisible(key, value) {
        settingsAdapter[key] = value;
        root.settingsFile.writeAdapter();
    }

    // Clock format — user-tunable from IslandSettings' "Clock format"
    // section. clockAmPmUppercase only matters in 12-hour mode; every clock
    // in the shell (Clock, IdleBump, WeatherPanel, Lock) reads timeFormat
    // rather than each hardcoding its own format string, so they always
    // agree with each other and with this setting.
    readonly property bool use24HourClock: settingsAdapter.use24HourClock
    readonly property bool clockAmPmUppercase: settingsAdapter.clockAmPmUppercase
    readonly property string timeFormat: root.use24HourClock ? "HH:mm"
        : root.clockAmPmUppercase ? "h:mm AP" : "h:mm ap"

    // Which reveal animation modules/wallpaper/Wallpaper.qml plays when the
    // wallpaper changes — "random" cycles through all of them, or pin one.
    readonly property string wallpaperRevealStyle: settingsAdapter.wallpaperRevealStyle
    readonly property var wallpaperRevealStyles: ["random", "blur", "glitch", "liquid", "grid", "neon", "honeycomb", "blinds"]

    function setWallpaperRevealStyle(style) {
        settingsAdapter.wallpaperRevealStyle = style;
        root.settingsFile.writeAdapter();
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("island-appearance.json")
        watchChanges: true

        JsonAdapter {
            id: settingsAdapter
            property int fontSize: 13
            property int idleBumpWidth: 140
            property int idleBumpHeight: 32
            property int islandTopGap: 10

            property bool showWorkspaces: true
            property bool showActiveWindow: true
            property bool showClock: true
            property bool showWeather: true
            property bool showTray: true
            property bool showStatusIndicators: true
            property bool showClipboard: false

            property bool showIdleMedia: true
            property bool showIdleClock: true
            property bool showIdleWeather: true
            property bool showIdleWorkspaces: false
            property bool showIdleActiveWindow: false
            property bool showIdleTray: false
            property bool showIdleStatusIndicators: false
            property bool showIdleClipboard: false

            property string wallpaperRevealStyle: "random"

            property bool use24HourClock: false
            property bool clockAmPmUppercase: true
        }
    }
}
