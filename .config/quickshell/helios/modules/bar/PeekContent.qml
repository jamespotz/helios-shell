import QtQuick
import "../../services"
import "../../components"

// Hover-expanded state — Apple menu bar philosophy: two clearly separated
// zones with generous internal spacing and a thin separator between them.
// Which widgets show, their order, and their side come from Config
// (Settings > Island); each zone self-hides when none of its widgets show.
Item {
    id: root

    required property var targetScreen

    readonly property var layout: Config.peekWidgetLayout
    readonly property var leftKeys: root.layout.slice(0, root.layout.indexOf("|"))
    readonly property var rightKeys: root.layout.slice(root.layout.indexOf("|") + 1)

    function shows(key) {
        if (!Config.widgetShown("peek", key)) return false;
        return key !== "weather" || Weather.available;
    }

    readonly property bool hasLeftCluster: root.leftKeys.some(k => root.shows(k))
    readonly property bool hasRightCluster: root.rightKeys.some(k => root.shows(k))

    implicitWidth: row.implicitWidth
    implicitHeight: Config.peekHeight

    readonly property var widgets: ({
        workspaces: workspacesWidget, tiledLayout: tiledLayoutWidget, activeWindow: activeWindowWidget,
        clock: clockWidget, weather: weatherWidget, tray: trayWidget,
        clipboard: clipboardWidget, statusIndicators: statusWidget, launcher: launcherWidget
    })

    // Inline components can't reach this file's ids, so the row is passed in.
    component Cluster: Row {
        id: cluster
        property var keys: []
        property var peek
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Repeater {
            model: cluster.keys

            Loader {
                required property string modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                active: Config.widgetShown("peek", modelData)
                // hasContent: widgets that hide themselves (tiled layout).
                visible: cluster.peek.shows(modelData) && (!item || item.hasContent !== false)
                sourceComponent: cluster.peek.widgets[modelData]
            }
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Cluster {
            visible: root.hasLeftCluster
            keys: root.leftKeys
            peek: root
        }

        // --- Separator between clusters ---
        Item {
            visible: root.hasLeftCluster && root.hasRightCluster
            width: 32
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: 14
                radius: 0.5
                color: Colors.overlay
                opacity: 0.3
            }
        }

        Cluster {
            visible: root.hasRightCluster
            keys: root.rightKeys
            peek: root
        }
    }

    Component {
        id: workspacesWidget
        Workspaces { targetScreen: root.targetScreen }
    }
    Component { id: launcherWidget; LauncherWidget { targetScreen: root.targetScreen } }

    Component {
        id: tiledLayoutWidget
        TiledLayoutIndicator { active: true; targetScreen: root.targetScreen }
    }

    Component {
        id: activeWindowWidget
        ActiveWindow { width: Math.min(implicitWidth, 200) }
    }

    Component {
        id: clockWidget
        Clock { targetScreen: root.targetScreen }
    }

    Component {
        id: weatherWidget
        WeatherWidget { targetScreen: root.targetScreen }
    }

    Component {
        id: trayWidget
        Tray {}
    }

    Component {
        id: clipboardWidget
        ClipboardWidget { targetScreen: root.targetScreen }
    }

    Component {
        id: statusWidget
        StatusIndicators { targetScreen: root.targetScreen }
    }
}
