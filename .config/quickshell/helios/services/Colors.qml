pragma Singleton
import QtQuick

// Live theme palette. Values here are just the "Helios" default — Themes.qml
// owns persistence/presets/dynamic-from-wallpaper generation and pushes a new
// palette in via apply() on startup and whenever the user switches themes.
QtObject {
    id: root

    property color background: "#14121a"
    property color surface: "#282331"
    property color surfaceHigh: "#3a3342"
    property color overlay: "#6f6580"
    property color text: "#eae6f0"
    property color subtext: "#b3a9c4"

    property color accent: "#f0a868"
    property color accentText: "#2c1c0f"
    property color danger: "#e5707e"
    property color warning: "#eec172"
    property color success: "#8fd08a"

    // Every UI element binds straight to these properties, so animating the
    // properties themselves (rather than each individual binding site) is
    // what makes switching themes read as a smooth crossfade instead of an
    // instant, jarring flip.
    Behavior on background { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surface { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surfaceHigh { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on overlay { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on text { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on subtext { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on accentText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on danger { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on warning { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on success { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }

    readonly property real panelOpacity: 0.96
    readonly property int radiusLarge: 20
    readonly property int radiusSmall: 10

    function apply(palette) {
        root.background = palette.background;
        root.surface = palette.surface;
        root.surfaceHigh = palette.surfaceHigh;
        root.overlay = palette.overlay;
        root.text = palette.text;
        root.subtext = palette.subtext;
        root.accent = palette.accent;
        root.accentText = palette.accentText;
        root.danger = palette.danger;
        root.warning = palette.warning;
        root.success = palette.success;
    }
}
