import QtQuick
import "../services"

// Vertical counterpart to Slider.qml, used by MediaCard's equalizer bands.
// Fill is bidirectional from centerValue (0dB) rather than bottom-up, so a
// band reads as "boosted" or "cut" the way a real EQ does.
Item {
    id: root

    property real value: 0.5 // 0..1
    property real centerValue: 0.5
    property color fillColor: Colors.accent
    // Spoken name for assistive tech.
    property string label: ""

    signal moved(real value)
    signal released()

    // A tick each time a drag or key step crosses a tenth of the range, like
    // a detent. Follows the value while idle so outside changes (volume keys)
    // don't tick on the next drag.
    property int _detent: Math.round(root.value * 10)
    onValueChanged: if (!dragArea.pressed) root._detent = Math.round(root.value * 10)
    function _move(v) {
        const detent = Math.round(v * 10);
        if (detent !== root._detent) AlertSounds.play("tick");
        root._detent = detent;
        root.moved(v);
    }

    implicitWidth: 18
    width: implicitWidth
    opacity: root.enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 2
        color: Colors.surfaceHigh

        Rectangle {
            // 0dB tie line
            anchors.horizontalCenter: parent.horizontalCenter
            width: 10
            height: 1
            color: Colors.overlay
            opacity: 0.6
            y: track.height * (1 - root.centerValue) - height / 2
        }

        Rectangle {
            readonly property real topFrac: 1 - Math.max(root.value, root.centerValue)
            readonly property real bottomFrac: 1 - Math.min(root.value, root.centerValue)

            width: parent.width
            radius: parent.radius
            color: root.fillColor
            y: track.height * topFrac
            height: Math.max(0, track.height * (bottomFrac - topFrac))
        }

        Rectangle {
            id: knob
            width: dragArea.pressed || knobHover.hovered || root.activeFocus ? 16 : 14
            height: width
            radius: width / 2
            color: Colors.text
            anchors.horizontalCenter: parent.horizontalCenter
            y: track.height * (1 - root.value) - height / 2

            Behavior on width { enabled: !Config.reducedMotion; Spring {} }

            // Focus ring — keyboard-navigation feedback
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 2
                border.color: Colors.accent
                visible: root.activeFocus
            }
        }

        HoverHandler { id: knobHover }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        enabled: root.enabled
        // The tab content sits in a vertically-scrolling Flickable
        // (IslandDestinationHost.qml) — without this, a vertical drag here gets
        // stolen by the Flickable's own scroll gesture instead of moving
        // the slider.
        preventStealing: true
        function posToValue(my) {
            return Math.max(0, Math.min(1, 1 - my / root.height));
        }
        onPressed: mouse => { root.forceActiveFocus(); root._move(posToValue(mouse.y)); }
        onPositionChanged: mouse => { if (pressed) root._move(posToValue(mouse.y)); }
        onReleased: root.released()
    }

    Accessible.role: Accessible.Slider
    Accessible.name: root.label
    Accessible.onIncreaseAction: root._move(Math.min(1, root.value + 0.05))
    Accessible.onDecreaseAction: root._move(Math.max(0, root.value - 0.05))

    activeFocusOnTab: root.enabled
    Keys.onUpPressed: if (root.enabled) root._move(Math.min(1, root.value + 0.05))
    Keys.onDownPressed: if (root.enabled) root._move(Math.max(0, root.value - 0.05))
}
