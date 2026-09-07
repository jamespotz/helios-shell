import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

// Workspace overview — Mission Control style: every workspace as a card,
// its windows as chips inside, search-as-you-type across all of them
// (Enter focuses the first match), drag a chip onto another workspace's
// card to move that window there. Window data comes from `hyprctl clients
// -j`, the same fetch-on-open pattern Launcher.qml already uses for its
// unified search's window results — duplicated here rather than shared
// because this view also needs per-workspace grouping and drag-drop that
// Launcher's flat result list has no use for.
PanelWindow {
    id: root

    visible: Bridge.overviewOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:overview"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    property var windows: []

    function refreshWindows() {
        windowsProc.running = false;
        windowsProc.running = true;
    }

    Process {
        id: windowsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text)
                        .filter(w => w.mapped !== false && w.title)
                        .map(w => ({
                            address: w.address,
                            title: w.title,
                            appClass: w["class"] || w.initialClass || "",
                            workspaceId: w.workspace ? w.workspace.id : -1
                        }));
                } catch (e) {
                    root.windows = [];
                }
            }
        }
    }

    // This Hyprland build parses dispatch strings as Lua (see AppLaunch.qml's
    // focusWindow()/Workspaces.qml's click handler for the same discovery) —
    // classic `hyprctl dispatch focuswindow address:X` is rejected outright
    // ("')' expected near 'address'", verified live). Window/workspace verbs
    // live under hl.dsp.window / hl.dsp.focus respectively, confirmed live
    // via `hyprctl dispatch` before wiring this in.
    function focusWindow(win) {
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + win.address + '" })');
        Bridge.closeOverview();
    }

    function focusWorkspace(wsId) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
        Bridge.closeOverview();
    }

    // Session-only chip order per workspace — hyprctl's own client order
    // isn't something a drag can rearrange, so dropping a chip records a
    // display order here instead. Merged over the live window list in
    // orderedWindows() below; addresses hyprctl no longer reports (closed
    // windows) just drop out next refresh, nothing to prune manually.
    property var order: ({})

    // beforeWin: drop target chip (insert before it), or null to drop at
    // the end (dropping on empty card space, or on the workspace itself).
    // Previously this bailed out entirely when win.workspaceId === wsId —
    // that's the "reordering within the same workspace does nothing" bug:
    // it skipped straight past any reordering because same-workspace was
    // treated as a no-op instead of "reposition without a hyprctl move".
    function moveWindow(win, wsId, beforeWin) {
        if (win.workspaceId !== wsId) {
            // Verified live this also switches the active workspace to the
            // target (there's no silent/no-follow variant on this
            // dispatcher) — acceptable here since the overview stays open
            // over it either way.
            Hyprland.dispatch('hl.dsp.window.move({ window = "address:' + win.address + '", workspace = ' + wsId + ' })');
            moveRefreshTimer.restart();
        }
        const current = root.orderedWindows(wsId).map(w => w.address).filter(a => a !== win.address);
        let insertAt = current.length;
        if (beforeWin) {
            const i = current.indexOf(beforeWin.address);
            if (i >= 0) insertAt = i;
        }
        current.splice(insertAt, 0, win.address);
        root.order = Object.assign({}, root.order, { [wsId]: current });
    }

    Timer { id: moveRefreshTimer; interval: 120; onTriggered: root.refreshWindows() }

    readonly property string query: searchField.text.trim().toLowerCase()

    function windowMatches(win) {
        if (!root.query) return true;
        return win.title.toLowerCase().includes(root.query) || win.appClass.toLowerCase().includes(root.query);
    }

    readonly property var sortedWorkspaces: {
        const list = Hyprland.workspaces ? Hyprland.workspaces.values.slice() : [];
        return list.sort((a, b) => a.id - b.id);
    }

    // Live thumbnails: ToplevelManager (wlr-foreign-toplevel-management, via
    // Quickshell.Wayland) has no window "address" to match hyprctl's clients
    // against directly, so pairing is by appId+title — the same tolerance
    // AppLaunch.qml already accepts for its own class-name matching. A miss
    // just means that chip falls back to its icon (ScreencopyView.hasContent
    // stays false), never a hard error.
    function toplevelFor(win) {
        const list = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
        return list.find(t => t.appId === win.appClass && t.title === win.title) || null;
    }

    function windowsForWorkspace(wsId) {
        return root.windows.filter(w => w.workspaceId === wsId && root.windowMatches(w));
    }

    // windowsForWorkspace() in the order the user last arranged them (if
    // any) — unarranged windows (never dragged, or newly opened) keep
    // hyprctl's own order and sort after any explicitly ordered ones.
    function orderedWindows(wsId) {
        const raw = root.windowsForWorkspace(wsId);
        const ord = root.order[wsId];
        if (!ord) return raw;
        const rank = new Map(ord.map((address, i) => [address, i]));
        return raw.slice().sort((a, b) => {
            const ra = rank.has(a.address) ? rank.get(a.address) : Infinity;
            const rb = rank.has(b.address) ? rank.get(b.address) : Infinity;
            return ra - rb;
        });
    }

    // First match across every workspace, in workspace-then-window order —
    // what Enter focuses.
    readonly property var firstMatch: {
        if (!root.query) return null;
        for (const ws of root.sortedWorkspaces) {
            const matches = root.windowsForWorkspace(ws.id);
            if (matches.length > 0) return matches[0];
        }
        return null;
    }

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            root.refreshWindows();
            searchField.focusInput();
        }
    }

    Scrim {
        active: root.visible
        onDismissed: Bridge.closeOverview()
    }

    Item {
        anchors.fill: parent
        Keys.onEscapePressed: Bridge.closeOverview()

        Item {
            id: card
            width: Math.min(parent.width - 80, 1100)
            height: Math.min(parent.height - 80, 720)
            anchors.centerIn: parent

            PanelBackground { anchors.fill: parent }

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 10

                    MaterialIcon {
                        icon: "grid_view"
                        font.pixelSize: 22
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: "Workspaces"
                        font.weight: Font.Bold
                        font.pixelSize: Config.fontSize + 4
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                SearchField {
                    id: searchField
                    width: parent.width
                    placeholder: "Search windows…"
                    onEscapePressed: Bridge.closeOverview()
                    onAccepted: if (root.firstMatch) root.focusWindow(root.firstMatch)
                }

                Flickable {
                    id: flick
                    width: parent.width
                    height: parent.height - 110
                    clip: true
                    contentWidth: width
                    contentHeight: grid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Flow {
                        id: grid
                        width: flick.width
                        spacing: 12

                        Repeater {
                            model: root.sortedWorkspaces

                            delegate: Rectangle {
                                id: wsCard
                                required property var modelData

                                readonly property var windowsHere: root.orderedWindows(wsCard.modelData.id)

                                width: 340
                                height: Math.max(120, chipFlow.implicitHeight + 56)
                                radius: Colors.radiusLarge
                                color: wsCard.modelData.focused ? Colors.surfaceHigh : Colors.surface
                                border.width: wsCard.modelData.urgent ? 2 : (dropArea.containsDrag ? 2 : 0)
                                border.color: wsCard.modelData.urgent ? Colors.danger : Colors.accent

                                // Catches drops on empty card space (append to the
                                // end) — a drop on a chip is instead handled by that
                                // chip's own DropArea below, which sits on top of this
                                // one and takes priority for the overlapping area.
                                DropArea {
                                    id: dropArea
                                    anchors.fill: parent
                                    onDropped: drag => root.moveWindow(drag.source.windowData, wsCard.modelData.id, null)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.focusWorkspace(wsCard.modelData.id)
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 8

                                    Row {
                                        spacing: 6
                                        StyledText {
                                            text: wsCard.modelData.name || String(wsCard.modelData.id)
                                            font.weight: Font.DemiBold
                                            color: wsCard.modelData.focused ? Colors.accent : Colors.text
                                        }
                                        MaterialIcon {
                                            visible: wsCard.modelData.urgent
                                            icon: "warning"
                                            font.pixelSize: 14
                                            color: Colors.danger
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    StyledText {
                                        visible: wsCard.windowsHere.length === 0
                                        text: "Empty"
                                        opacity: 0.4
                                        font.pixelSize: Config.fontSize - 3
                                    }

                                    Flow {
                                        id: chipFlow
                                        width: parent.width
                                        spacing: 6

                                        Repeater {
                                            model: wsCard.windowsHere

                                            delegate: Rectangle {
                                                id: chip
                                                required property var modelData
                                                readonly property var windowData: chip.modelData
                                                readonly property var toplevel: root.toplevelFor(chip.modelData)

                                                width: 148
                                                height: 108
                                                radius: 10
                                                color: Colors.surfaceHigh
                                                clip: true
                                                border.width: chipHover.hovered ? 2 : 0
                                                border.color: Colors.accent

                                                Drag.active: chipDrag.drag.active
                                                Drag.hotSpot.x: width / 2
                                                Drag.hotSpot.y: height / 2

                                                // Reparent to the top-level dragLayer for the
                                                // duration of the drag so the chip paints above
                                                // every workspace card instead of being occluded
                                                // by a later sibling (see dragLayer's comment) —
                                                // preserve on-screen position across the reparent
                                                // since x/y are otherwise relative to the new parent.
                                                Drag.onActiveChanged: {
                                                    if (chip.Drag.active) {
                                                        const pos = chip.mapToItem(dragLayer, 0, 0);
                                                        chip.parent = dragLayer;
                                                        chip.x = pos.x;
                                                        chip.y = pos.y;
                                                    }
                                                }

                                                HoverHandler { id: chipHover }

                                                // Dropping another chip onto this one inserts
                                                // the dragged window right before this one — the
                                                // actual fix for "rearranging within the same
                                                // workspace does nothing": that always hit
                                                // wsCard's DropArea instead, which only ever
                                                // appended to the end and, for a same-workspace
                                                // drag, used to no-op entirely.
                                                DropArea {
                                                    anchors.fill: parent
                                                    onDropped: drag => {
                                                        const dragged = drag.source.windowData;
                                                        if (dragged.address === chip.modelData.address) return;
                                                        root.moveWindow(dragged, wsCard.modelData.id, chip.modelData);
                                                    }
                                                }

                                                ScreencopyView {
                                                    id: preview
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    height: 80
                                                    captureSource: chip.toplevel
                                                    live: root.visible
                                                    visible: hasContent
                                                }

                                                Image {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    height: 80
                                                    visible: !preview.hasContent
                                                    source: Quickshell.iconPath(chip.modelData.appClass, true)
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                }

                                                StyledText {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 6
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    text: chip.modelData.title
                                                    font.pixelSize: Config.fontSize - 3
                                                    color: Colors.text
                                                }

                                                MouseArea {
                                                    id: chipDrag
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    drag.target: chip
                                                    onClicked: root.focusWindow(chip.modelData)
                                                    onReleased: {
                                                        chip.Drag.drop();
                                                        root.refreshWindows();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // A chip being dragged lives inside its origin workspace card's own
        // subtree, so once the cursor crosses into a later sibling card,
        // that card's opaque background paints over it — QtQuick's paint
        // order is hierarchical, a child's z can't win against an unrelated
        // later sibling of its ancestor. Reparenting the chip up here for
        // the duration of the drag (see chip's Drag.onActiveChanged below)
        // is the actual fix; z-index alone can't solve cross-subtree
        // occlusion. Declared last so it paints above every workspace card.
        Item { id: dragLayer; anchors.fill: parent }
    }
}
