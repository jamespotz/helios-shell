import QtQuick
import "../services"

// Apple-style vibrancy surface: Hyprland supplies the real blur (via
// `layerrule blur` for the "helios:bar" namespace in shell.qml); this
// surface only paints a neutral tint + subtle specular rim on top.
// Falls back to a flat fill (a Rectangle child) when liquid glass is disabled.
//
// Design principle: Apple's dark vibrancy materials are almost entirely
// neutral gray with very slight warmth — no colored tints. The blur
// itself provides the color from what's behind.
Item {
    id: root

    property bool active: false
    property real cornerRadius: 8
    property color fallbackColor: Colors.background
    property real glassAmount: active ? 1 : 0
    readonly property real _radius: Math.min(cornerRadius, width / 2, height / 2)

    // Plain Rectangles, not Canvas: a Canvas texture isn't antialiased at
    // fractional output scale (e.g. 1.25), so rounded caps rendered as hard
    // stair steps that read as a cropped edge. Rectangles also follow theme
    // and size changes through bindings, with no repaint per spring frame.
    Item {
        anchors.fill: parent
        opacity: root.glassAmount
        visible: opacity > 0.001

        // Neutral tint — Apple vibrancy is almost monochrome gray, letting
        // the blurred wallpaper underneath provide color. Drawn from the
        // live theme's surface/background tokens so it follows theme
        // switches instead of being locked to one fixed dark palette.
        Rectangle {
            anchors.fill: parent
            radius: root._radius
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Colors.surface, 0.72) }
                GradientStop { position: 1; color: Qt.alpha(Colors.background, 0.78) }
            }
        }

        // Subtle vignette darkening at the bottom edge — adds depth
        // without being distracting.
        Rectangle {
            anchors.fill: parent
            radius: root._radius
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.6; color: Qt.alpha(Colors.shadow, 0) }
                GradientStop { position: 1; color: Qt.alpha(Colors.shadow, 0.08) }
            }
        }

        // Top-edge specular rim — the way Apple dark materials catch ambient
        // light. Kept a literal white rather than a theme token: this is a
        // physical light-catch reflection, not UI chrome, so it stays white
        // in every theme the same way a real glass edge would.
        Rectangle {
            anchors.fill: parent
            radius: root._radius
            antialiasing: true
            color: "transparent"
            border.width: 0.75
            border.color: Qt.rgba(1, 1, 1, 0.14)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root._radius
        antialiasing: true
        color: root.fallbackColor
        opacity: 1 - root.glassAmount
        visible: opacity > 0.001
    }

    Behavior on glassAmount {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
}
