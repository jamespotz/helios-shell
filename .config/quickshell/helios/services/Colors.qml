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

    // Full Material/matugen role set — additive to the legacy properties
    // above (which every existing component still binds to). Populated by
    // Themes.qml's apply() alongside the legacy roles, either straight from
    // matugen (dynamic mode) or derived from a preset's legacy colors (see
    // Themes.deriveFullPalette). New components should prefer these names;
    // old ones are untouched.
    //
    // Material's "on<Role>" naming (onBackground, onPrimary, ...) can't be
    // used verbatim here — QML reserves any property name starting with
    // "on" + a capital letter for signal handlers (`property color onError`
    // fails to even load, "Cannot assign a value to a signal"), regardless
    // of whether a matching signal exists. These use a "<role>Text" suffix
    // instead, matching the "accentText" convention the legacy properties
    // above already use for the same reason.
    property color backgroundText: "#eae6f0"
    property color surfaceText: "#eae6f0"
    property color surfaceVariant: "#3a3342"
    property color surfaceVariantText: "#b3a9c4"
    property color surfaceContainer: "#282331"
    property color surfaceContainerLow: "#14121a"
    property color surfaceContainerHigh: "#3a3342"

    property color primary: "#f0a868"
    property color primaryText: "#2c1c0f"
    property color primaryContainer: "#f0a868"
    property color primaryContainerText: "#2c1c0f"

    property color secondary: "#f0a868"
    property color secondaryText: "#2c1c0f"
    property color secondaryContainer: "#f0a868"
    property color secondaryContainerText: "#2c1c0f"

    property color tertiary: "#f0a868"
    property color tertiaryText: "#2c1c0f"
    property color tertiaryContainer: "#f0a868"
    property color tertiaryContainerText: "#2c1c0f"

    property color error: "#e5707e"
    property color errorText: "#2c1c0f"
    property color outline: "#6f6580"
    property color shadow: "#000000"

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

    Behavior on backgroundText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surfaceText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surfaceVariant { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surfaceVariantText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surfaceContainer { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surfaceContainerLow { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on surfaceContainerHigh { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on primary { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on primaryText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on primaryContainer { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on primaryContainerText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on secondary { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on secondaryText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on secondaryContainer { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on secondaryContainerText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on tertiary { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on tertiaryText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on tertiaryContainer { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on tertiaryContainerText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on error { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on errorText { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on outline { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on shadow { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }

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
