import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../components"

// Apple Control Center-inspired panel container. Tab switching happens over
// IPC only (`island toggle <tab>`); this just renders whichever tab is
// active plus a close button. Content scrolls when tall.
Item {
    id: root

    // Empty (the default) follows whatever the main island currently has
    // open — right for the main island's own panelComp. A satellite reusing
    // this wrapper to pre-warm one fixed destination (e.g. "maintenance")
    // needs to pin it here instead: IslandNavigation.current is a single
    // global value, so left at the default it would follow the main
    // island's destination too and instantiate the wrong panel (and its
    // side effects — Processes, canvas bindings, etc.) behind the badge.
    property string destinationId: ""
    readonly property var destination: root.destinationId ? IslandNavigation.resolve(root.destinationId) : IslandNavigation.current

    readonly property int maxContentHeight: Config.islandMaxHeight - 120
    readonly property int marginSize: 8

    // A tab's implicitHeight has to stay bound to its TRUE full content
    // height (see e.g. IslandSettings.qml's `implicitHeight: col.implicitHeight`)
    // because that same number also drives the Flickable's contentHeight
    // below — shrink it and the tab doesn't get shorter, it just loses the
    // ability to scroll to whatever content that number no longer accounts
    // for. To make a specific tab render shorter (and scrollable) without
    // touching its real content height, cap its effective viewport height
    // here instead, per tab.
    readonly property int _effectiveMaxHeight: root.destination && root.destination.maxHeight > 0 ? root.destination.maxHeight : root.maxContentHeight

    implicitWidth: pane.width
    implicitHeight: pane.spacing + root.marginSize + Math.min(panelLoader.implicitHeight, root._effectiveMaxHeight)

    ColumnLayout {
        id: pane
        // Floor is a defensive minimum, well below any real tab's implicitWidth.
        width: Math.max(220, panelLoader.implicitWidth) + (marginSize * 2)
        spacing: 14

        // ─── Scrollable content area ─────────────────────────────────────
        Rectangle {
            id: scrollWrap
            color: "transparent"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(panelLoader.implicitHeight, root._effectiveMaxHeight)
            Layout.margins: root.marginSize

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: panelLoader.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Loader {
                    id: panelLoader
                    width: flick.width
                    source: root.destination ? root.destination.source : ""
                    opacity: 0
                    onLoaded: panelFadeIn.restart()

                    NumberAnimation {
                        id: panelFadeIn
                        target: panelLoader
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 550
                        easing.type: Easing.BezierSpline
                    }
                }
            }

            ScrollIndicator {
                target: flick
            }
        }
    }
}
