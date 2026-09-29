import QtQuick
import Quickshell.Hyprland
import "../../components"
import "../../services"

// Apple-style workspace indicators. "dots" style: rounded pill for the
// active workspace, small dots for others. "numbers" and "custom" styles:
// one glyph per workspace (counter_N, or the user's icon in custom) — a
// filled badge slides to the active workspace, or, when only the current
// workspace is shown, the glyph rolls like an odometer.
Item {
    id: root

    required property var targetScreen
    readonly property var monitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    readonly property var activeWs: monitor ? monitor.activeWorkspace : Hyprland.focusedWorkspace
    // Glyph styles — "numbers" and "custom" share layout and motion.
    readonly property bool numbers: Config.workspaceIndicatorStyle !== "dots"
    readonly property bool custom: Config.workspaceIndicatorStyle === "custom"
    readonly property bool rolling: numbers && !Config.showAllWorkspaces

    // Delegate showing the active workspace — the sliding badge tracks it.
    readonly property Item activeItem: {
        const ws = root.activeWs;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item && item.modelData === ws)
                return item;
        }
        return null;
    }

    implicitWidth: rolling ? roller.width : row.implicitWidth
    implicitHeight: rolling ? roller.height : row.implicitHeight

    // Custom icon when set; otherwise counter_N, which only exists for 0–9 —
    // higher ids fall back to plain text.
    component WorkspaceGlyph: Item {
        id: wsGlyph
        property var workspace: null
        property bool filled: false
        property color color: Colors.text
        readonly property int wsId: workspace ? workspace.id : 0
        readonly property string customIcon: root.custom ? (Config.workspaceIcons[wsId] || "") : ""
        readonly property bool hasGlyph: customIcon !== "" || (wsId >= 0 && wsId <= 9)

        implicitWidth: icon.implicitWidth
        implicitHeight: icon.implicitHeight

        MaterialIcon {
            id: icon
            anchors.centerIn: parent
            icon: wsGlyph.customIcon || "counter_" + (wsGlyph.hasGlyph ? wsGlyph.wsId : 0)
            opacity: wsGlyph.hasGlyph ? 1 : 0
            filled: wsGlyph.filled
            color: wsGlyph.color
        }
        StyledText {
            anchors.centerIn: parent
            visible: !wsGlyph.hasGlyph
            text: wsGlyph.workspace ? wsGlyph.workspace.name : ""
            color: wsGlyph.color
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.rolling
        spacing: root.numbers ? 2 : 6

        Repeater {
            id: repeater
            model: Hyprland.workspaces

            delegate: Item {
                id: dot
                required property var modelData

                readonly property color tint: modelData.focused ? Colors.accent
                    : modelData.urgent ? Colors.danger
                    : root.numbers ? Colors.text : Colors.overlay

                visible: root.monitor === null || modelData.monitor === root.monitor
                width: root.numbers ? glyph.implicitWidth : (modelData.focused ? 22 : 7)
                height: root.numbers ? glyph.implicitHeight : 7
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                opacity: modelData.focused ? 1 : 0.6

                Behavior on width { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                Rectangle {
                    anchors.fill: parent
                    visible: !root.numbers
                    radius: height / 2
                    color: dot.tint
                    Behavior on color { ColorAnimation { duration: Config.animFast } }
                }

                // Outline glyph — the active slot's stays hidden under the badge.
                WorkspaceGlyph {
                    id: glyph
                    anchors.centerIn: parent
                    visible: root.numbers
                    opacity: root.activeItem === dot ? 0 : 1
                    workspace: dot.modelData
                    color: dot.tint
                }

                // Hover ring — subtle outline on non-focused workspaces
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Colors.text
                    opacity: dotHover.hovered && !dot.modelData.focused ? 0.3 : 0
                    Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                }

                HoverHandler { id: dotHover }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.modelData.id + " })")
                }
            }
        }
    }

    // Sliding badge — a filled glyph that travels from the previous active
    // workspace to the new one. Retargets mid-flight on quick switches.
    WorkspaceGlyph {
        id: badge
        visible: root.numbers && !root.rolling && root.activeItem !== null
        x: row.x + (root.activeItem ? root.activeItem.x : 0)
        anchors.verticalCenter: parent.verticalCenter
        workspace: root.activeWs
        filled: true
        color: Colors.accent

        Behavior on x {
            enabled: badge.visible && !Config.reducedMotion
            NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
        }
    }

    // Odometer roll — only the current workspace is shown; the old number
    // slides out as the new one slides in. Up for a higher id, down for lower.
    Item {
        id: roller
        visible: root.rolling
        anchors.verticalCenter: parent.verticalCenter
        width: incoming.implicitWidth
        height: incoming.implicitHeight
        clip: true

        readonly property real shift: Config.reducedMotion ? 0 : 7
        property var previous: null
        property var current: null
        property int direction: 1
        property real progress: 1

        Component.onCompleted: current = root.activeWs

        Connections {
            target: root
            function onActiveWsChanged() {
                const next = root.activeWs;
                if (roller.visible && next && roller.current) {
                    roller.previous = roller.current;
                    roller.direction = next.id > roller.current.id ? 1 : -1;
                    roller.current = next;
                    rollAnim.restart();
                } else {
                    roller.current = next;
                }
            }
        }

        NumberAnimation {
            id: rollAnim
            target: roller
            property: "progress"
            from: 0
            to: 1
            duration: Config.animMedium
            easing.type: Easing.OutCubic
        }

        WorkspaceGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -roller.direction * roller.shift * roller.progress
            opacity: 1 - roller.progress
            visible: roller.progress < 1 && roller.previous !== null
            workspace: roller.previous
            filled: true
            color: Colors.accent
        }
        WorkspaceGlyph {
            id: incoming
            anchors.horizontalCenter: parent.horizontalCenter
            y: roller.direction * roller.shift * (1 - roller.progress)
            opacity: roller.progress
            workspace: roller.current
            filled: true
            color: Colors.accent
        }
    }
}
