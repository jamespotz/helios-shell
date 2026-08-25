pragma Singleton
import QtQuick
import "../services"

// Live theme palette — Apple-inspired dark mode with neutral grays, high
// contrast text, and a cool blue accent. Themes.qml can still override
// everything via apply().
QtObject {
    id: root

    property color background: "#1c1c1e"
    property color surface: "#2c2c2e"
    property color surfaceHigh: "#3a3a3c"
    property color overlay: "#636366"
    property color text: "#f5f5f7"
    property color subtext: "#98989d"

    property color accent: "#0a84ff"
    property color accentText: "#ffffff"
    property color danger: "#ff453a"
    property color warning: "#ffd60a"
    property color success: "#30d158"

    // Full role set — Apple's semantic palette translated into the same
    // property structure Themes.qml expects. Neutral, desaturated grays with
    // generous contrast separation between layers.
    property color backgroundText: "#f5f5f7"
    property color surfaceText: "#f5f5f7"
    property color surfaceVariant: "#3a3a3c"
    property color surfaceVariantText: "#98989d"
    property color surfaceContainer: "#2c2c2e"
    property color surfaceContainerLow: "#1c1c1e"
    property color surfaceContainerHigh: "#3a3a3c"

    property color primary: "#0a84ff"
    property color primaryText: "#ffffff"
    property color primaryContainer: "#1a3a5c"
    property color primaryContainerText: "#64b5f6"

    property color secondary: "#5e5ce6"
    property color secondaryText: "#ffffff"
    property color secondaryContainer: "#2d2b5e"
    property color secondaryContainerText: "#a5a4f3"

    property color tertiary: "#bf5af2"
    property color tertiaryText: "#ffffff"
    property color tertiaryContainer: "#3d2052"
    property color tertiaryContainerText: "#d9a1f7"

    property color error: "#ff453a"
    property color errorText: "#ffffff"
    property color outline: "#48484a"
    property color shadow: "#000000"

    // Every UI element binds straight to these properties, so animating the
    // properties themselves (rather than each individual binding site) is
    // what makes switching themes read as a smooth crossfade instead of an
    // instant, jarring flip.
    Behavior on background { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surface { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surfaceHigh { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on overlay { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on text { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on subtext { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on accentText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on danger { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on warning { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on success { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }

    Behavior on backgroundText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surfaceText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surfaceVariant { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surfaceVariantText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surfaceContainer { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surfaceContainerLow { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on surfaceContainerHigh { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on primary { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on primaryText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on primaryContainer { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on primaryContainerText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on secondary { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on secondaryText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on secondaryContainer { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on secondaryContainerText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on tertiary { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on tertiaryText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on tertiaryContainer { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on tertiaryContainerText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on error { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on errorText { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on outline { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }
    Behavior on shadow { ColorAnimation { duration: Config.animSlow; easing.type: Easing.OutCubic } }

    // Apple-style material: more translucent to let vibrancy through
    readonly property real panelOpacity: 0.82
    // Apple uses larger radii — continuous (squircle-like) corners
    readonly property int radiusLarge: 16
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

        root.backgroundText = palette.backgroundText;
        root.surfaceText = palette.surfaceText;
        root.surfaceVariant = palette.surfaceVariant;
        root.surfaceVariantText = palette.surfaceVariantText;
        root.surfaceContainer = palette.surfaceContainer;
        root.surfaceContainerLow = palette.surfaceContainerLow;
        root.surfaceContainerHigh = palette.surfaceContainerHigh;

        root.primary = palette.primary;
        root.primaryText = palette.primaryText;
        root.primaryContainer = palette.primaryContainer;
        root.primaryContainerText = palette.primaryContainerText;

        root.secondary = palette.secondary;
        root.secondaryText = palette.secondaryText;
        root.secondaryContainer = palette.secondaryContainer;
        root.secondaryContainerText = palette.secondaryContainerText;

        root.tertiary = palette.tertiary;
        root.tertiaryText = palette.tertiaryText;
        root.tertiaryContainer = palette.tertiaryContainer;
        root.tertiaryContainerText = palette.tertiaryContainerText;

        root.error = palette.error;
        root.errorText = palette.errorText;
        root.outline = palette.outline;
        root.shadow = palette.shadow;
    }
}
