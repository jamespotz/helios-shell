import QtQuick
import "../services"

// Shared list-row shell for the island's settings tabs (Wifi/Bluetooth/
// Volume device+network lists): background + hover highlight + click.
// Extracted after the same hand-rolled Rectangle/HoverHandler/MouseArea trio
// was copy-pasted into all three tabs and kept re-breaking in slightly
// different ways (hover bleeding into a neighboring row, mainly from
// oversized nested hit areas) — one correct implementation beats three
// drifting copies. Put row content (icons/text/etc.) as normal children.
Rectangle {
    id: root

    // True for a persistent state (connected/default/selected) that should
    // stay highlighted regardless of hover.
    property bool highlighted: false
    readonly property bool hovering: hoverHandler.hovered

    signal clicked()

    height: 44
    radius: Colors.radiusSmall
    // `highlighted` (persistent — connected/default/selected) and hover are
    // layered rather than picking one color, so hovering a highlighted row
    // still visibly reacts. Colors.surface (the old hover color) is the
    // same color as the panel's own background, so the hover was nearly
    // invisible — Colors.overlay reads clearly against either.
    color: highlighted ? Colors.surfaceHigh : "transparent"
    Behavior on color { ColorAnimation { duration: Config.animFast } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.overlay
        opacity: root.hovering ? (root.highlighted ? 0.18 : 0.28) : 0
        Behavior on opacity { NumberAnimation { duration: Config.animFast } }
    }

    // HoverHandler (not a plain hoverEnabled MouseArea) tracks this row's
    // own bounds independently of any nested MouseArea painted on top of it
    // (e.g. a per-row action icon) — a plain MouseArea loses hover the
    // instant the cursor crosses onto a child MouseArea, which read as the
    // highlight flickering/jumping.
    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
