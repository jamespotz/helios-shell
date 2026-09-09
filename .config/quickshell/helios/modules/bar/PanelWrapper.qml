import QtQuick
import "../../services"
import "../../components"

// Apple Control Center-inspired panel container. Tab switching happens over
// IPC only (`island toggle <tab>`); this just renders whichever tab is
// active plus a close button. Content scrolls when tall.
Item {
    id: root

    readonly property int maxContentHeight: Config.islandMaxHeight - 120

    // A tab's implicitHeight has to stay bound to its TRUE full content
    // height (see e.g. IslandSettings.qml's `implicitHeight: col.implicitHeight`)
    // because that same number also drives the Flickable's contentHeight
    // below — shrink it and the tab doesn't get shorter, it just loses the
    // ability to scroll to whatever content that number no longer accounts
    // for. To make a specific tab render shorter (and scrollable) without
    // touching its real content height, cap its effective viewport height
    // here instead, per tab.
    readonly property int _effectiveMaxHeight: IslandNavigation.current && IslandNavigation.current.maxHeight > 0
        ? IslandNavigation.current.maxHeight : root.maxContentHeight

    implicitWidth: pane.width
    implicitHeight: tabs.height + pane.spacing + Math.min(panelLoader.implicitHeight, root._effectiveMaxHeight)

    Column {
        id: pane
        // Floor is a defensive minimum, well below any real tab's implicitWidth.
        width: Math.max(220, panelLoader.implicitWidth)
        spacing: 14

        // ─── Header: current tab label + close. Tab switching is IPC-only
        // now (`quickshell -c helios ipc call island toggle <tab>`) — no
        // in-panel icon row.
        Item {
            id: tabs
            width: pane.width
            height: 28

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: IslandNavigation.current ? IslandNavigation.current.label : ""
                opacity: 0.6
                font.pixelSize: Config.fontSize - 1
            }

            IconButton {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                icon: "close"
                iconSize: 14
                iconColor: Colors.subtext
                onClicked: IslandNavigation.close()
            }
        }

        // ─── Scrollable content area ─────────────────────────────────────
        Item {
            id: scrollWrap
            width: pane.width
            height: Math.min(panelLoader.implicitHeight, root._effectiveMaxHeight)

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
                    source: IslandNavigation.current ? IslandNavigation.current.source : ""
                }
            }

            ScrollIndicator { target: flick }
        }
    }

}
