import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "../../components"

// Apple Spotlight-inspired launcher — prominent search field, clean result
// rows with rounded app icons, smooth keyboard navigation. Terminal apps
// (btop, nvim, etc.) are automatically spawned inside Config.terminal.
Item {
    id: root

    readonly property int listHeight: 380

    // Right-click context menu — freedesktop "Desktop Actions" for the app
    // under contextMenuEntry (e.g. Ghostty's "New Window"), positioned at
    // contextMenuPos in this item's own coordinate space. null entry
    // means no menu is open.
    property var contextMenuEntry: null
    property point contextMenuPos: Qt.point(0, 0)
    readonly property var results: Launcher.results
    readonly property bool emojiMode: Launcher.emojiMode
    readonly property bool searchFocused: searchField.inputActiveFocus
    readonly property bool gridMode: Launcher.view === "grid" && !root.emojiMode
    readonly property int gridColumns: 5
    readonly property Item resultView: root.gridMode ? appGrid : resultList
    readonly property var contextMenuEntries: {
        const entry = root.contextMenuEntry;
        if (!entry) return [];
        const key = Dock.keyOf(entry);
        const pinned = Dock.pins.includes(key);
        return (entry.actions || []).map(action => ({ label: action.name, run: () => root.runAction(action) }))
            .concat([{ label: pinned ? "Remove from Dock" : "Add to Dock", run: () => pinned ? Dock.unpin(key) : Dock.pin(key) }]);
    }

    function refresh() {
        Launcher.search(searchField.text);
        root.resultView.currentIndex = results.length > 0 ? Math.min(root.resultView.currentIndex, results.length - 1) : 0;
    }
    function moveSelection(delta) {
        if (results.length === 0) return;
        root.resultView.currentIndex = Math.max(0, Math.min(root.resultView.currentIndex + delta, results.length - 1));
    }
    function closeContextMenu() {
        root.contextMenuEntry = null;
        searchField.focusInput();
    }
    function openContextMenu(entry, pos) {
        root.contextMenuPos = pos;
        root.contextMenuEntry = entry;
        contextMenu.forceActiveFocus();
    }
    function refreshWindows() { Launcher.refreshWindows(); }
    function focusSearch() { searchField.focusInput(); }
    function activateResult(result) { Launcher.activate(result); }
    function copyEmoji(entry) { Launcher.activate({ activation: { kind: "emoji", value: entry.emoji } }); }
    function runAction(action) { Launcher.runDesktopAction(action, root.contextMenuEntry ? root.contextMenuEntry.name : ""); }

    Component.onCompleted: {
        searchField.text = "";
        root.refresh();
        root.refreshWindows();
        focusSearchTimer.restart();
        resultList.currentIndex = 0;
    }

    // Bar establishes its Hyprland keyboard grab shortly after loading.
    // Focus after that handoff so the grab cannot leave focus on the panel.
    Timer {
        id: focusSearchTimer
        interval: 120
        onTriggered: root.focusSearch()
    }

    implicitWidth: contentCol.width
    implicitHeight: contentCol.implicitHeight

    Column {
        id: contentCol
        width: 480
        spacing: 12

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "search"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Launcher"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        // Search field — prominent, Apple-style — plus a trigger button
        // that pre-fills the "/em " prefix for anyone who won't remember
        // to type it themselves.
        Row {
            width: parent.width
            spacing: 8

            SearchField {
                id: searchField
                width: parent.width - emojiButton.width - allAppsButton.width - parent.spacing * 2
                placeholder: "Search apps, windows, settings…"
                inputPixelSize: Config.fontSize + 2

                onTextChanged: root.refresh()
                onEscapePressed: {
                    if (root.contextMenuEntry) root.closeContextMenu();
                    else IslandNavigation.close();
                }
                captureHorizontal: root.gridMode
                onDownPressed: root.moveSelection(root.gridMode ? root.gridColumns : 1)
                onUpPressed: root.moveSelection(root.gridMode ? -root.gridColumns : -1)
                onLeftPressed: root.moveSelection(-1)
                onRightPressed: root.moveSelection(1)
                onAccepted: {
                    if (results.length === 0) return;
                    const result = results[root.resultView.currentIndex];
                    root.activateResult(result);
                }
            }

            IconButton {
                id: allAppsButton
                icon: "apps"
                iconSize: 18
                label: "All Applications"
                anchors.verticalCenter: parent.verticalCenter
                active: root.gridMode
                onClicked: {
                    if (root.emojiMode) searchField.text = "";
                    Launcher.setView(root.gridMode ? "list" : "grid");
                    root.resultView.currentIndex = 0;
                    searchField.focusInput();
                }
            }

            IconButton {
                id: emojiButton
                icon: "add_reaction"
                iconSize: 18
                anchors.verticalCenter: parent.verticalCenter
                active: root.emojiMode
                onClicked: {
                    searchField.text = "/em ";
                    searchField.cursorPosition = searchField.text.length;
                    searchField.focusInput();
                }
            }
        }

        // Results list — fixed height like KeybindsIsland's listHeight, so
        // opening the launcher or typing a query never resizes the island.
        Item {
            width: parent.width
            height: root.listHeight

            ListView {
                id: resultList
                anchors.fill: parent
                visible: results.length > 0 && !root.gridMode
                clip: true
                model: root.gridMode ? [] : results
                spacing: 2
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: resultRow
                    required property var modelData
                    required property int index

                    readonly property string kind: modelData.kind
                    readonly property var entry: modelData.entry
                    readonly property string title: modelData.title
                    readonly property string subtitle: kind === "action" ? "Action"
                        : kind === "emoji" ? (entry.category || "") : modelData.subtitle

                    width: resultList.width
                    height: 50
                    radius: 10
                    color: index === resultList.currentIndex ? Colors.accent
                        : resultHover.hovered ? Colors.surfaceHigh : "transparent"

                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    HoverHandler { id: resultHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        // Icon — app icon image, emoji glyph, or a Material
                        // icon for windows/actions.
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: index === resultList.currentIndex ? Qt.rgba(Colors.accentText.r, Colors.accentText.g, Colors.accentText.b, 0.15) : Colors.surfaceHigh
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                visible: resultRow.kind === "app"
                                source: resultRow.kind === "app" ? Quickshell.iconPath(resultRow.entry.icon, true) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            StyledText {
                                anchors.centerIn: parent
                                visible: resultRow.kind === "emoji"
                                text: resultRow.kind === "emoji" ? resultRow.entry.emoji : ""
                                font.pixelSize: 19
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: resultRow.kind === "window" || resultRow.kind === "action"
                                icon: resultRow.kind === "window" ? "desktop_windows" : resultRow.entry.icon
                                font.pixelSize: 18
                                color: index === resultList.currentIndex ? Colors.accentText : Colors.subtext
                            }
                        }

                        // Name + description (apps: generic name; windows:
                        // app class; actions: "Action"; emoji: category)
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36 - 12 - 10 - termBadge.width - 10
                            spacing: 1

                            StyledText {
                                text: resultRow.title
                                font.weight: Font.Medium
                                color: index === resultList.currentIndex ? Colors.accentText : Colors.text
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            StyledText {
                                visible: !!resultRow.subtitle
                                text: resultRow.subtitle
                                font.pixelSize: Config.fontSize - 2
                                color: index === resultList.currentIndex ? Qt.rgba(Colors.accentText.r, Colors.accentText.g, Colors.accentText.b, 0.7) : Colors.subtext
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }

                        // Terminal badge — shows when app needs terminal
                        Rectangle {
                            id: termBadge
                            visible: resultRow.kind === "app" && resultRow.entry.runInTerminal === true
                            width: visible ? termRow.implicitWidth + 10 : 0
                            height: 20
                            radius: 10
                            color: index === resultList.currentIndex ? Qt.rgba(Colors.accentText.r, Colors.accentText.g, Colors.accentText.b, 0.2) : Colors.surfaceHigh
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                id: termRow
                                anchors.centerIn: parent
                                spacing: 3
                                MaterialIcon {
                                    icon: "terminal"
                                    font.pixelSize: 11
                                    color: index === resultList.currentIndex ? Colors.accentText : Colors.subtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: "CLI"
                                    font.pixelSize: Config.fontSize - 3
                                    font.weight: Font.Medium
                                    color: index === resultList.currentIndex ? Colors.accentText : Colors.subtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: resultMouseArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (resultRow.kind === "app") root.openContextMenu(resultRow.entry, resultMouseArea.mapToItem(root, mouse.x, mouse.y));
                                return;
                            }
                            if (resultRow.kind === "emoji") root.copyEmoji(resultRow.entry);
                            else root.activateResult(resultRow.modelData);
                        }
                    }
                }
            }

            // All applications — icon grid, same selection colors as the list.
            GridView {
                id: appGrid
                anchors.fill: parent
                visible: results.length > 0 && root.gridMode
                clip: true
                model: root.gridMode ? results : []
                cellWidth: width / root.gridColumns
                cellHeight: 100
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: appCell
                    required property var modelData
                    required property int index
                    readonly property bool current: index === appGrid.currentIndex

                    width: appGrid.cellWidth
                    height: appGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 12
                        color: appCell.current ? Colors.accent
                            : cellMouse.containsMouse ? Colors.surfaceHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: Config.animFast } }
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 6

                        Item {
                            width: 48
                            height: 48
                            anchors.horizontalCenter: parent.horizontalCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: cellIcon.source.toString() === ""
                                icon: "deployed_code"
                                font.pixelSize: 36
                                color: appCell.current ? Colors.accentText : Colors.subtext
                            }
                            Image {
                                id: cellIcon
                                anchors.fill: parent
                                source: Quickshell.iconPath(appCell.modelData.entry.icon, true)
                                sourceSize: Qt.size(96, 96)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }
                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: appCell.modelData.title
                            font.pixelSize: Config.fontSize - 1
                            color: appCell.current ? Colors.accentText : Colors.text
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) root.openContextMenu(appCell.modelData.entry, cellMouse.mapToItem(root, mouse.x, mouse.y));
                            else root.activateResult(appCell.modelData);
                        }
                    }
                }
            }

            // Empty state
            Item {
                visible: results.length === 0 && searchField.text.length > 0
                anchors.centerIn: parent
                width: parent.width
                height: 60

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon { icon: "search_off"; font.pixelSize: 24; color: Colors.overlay; anchors.horizontalCenter: parent.horizontalCenter }
                    StyledText { text: root.emojiMode ? "No matching emoji" : "No results"; color: Colors.subtext; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
        }
    }

    // Right-click context menu — freedesktop Desktop Actions for the app
    // under contextMenuEntry. Kept as its own top-level popup (not nested
    // in the result delegate) so it isn't clipped by the ListView, and
    // positioned in this item's own coordinate space since it's a sibling
    // of contentCol rather than a reparented window-level overlay.
    Scrim {
        active: root.contextMenuEntry !== null
        dimOpacity: 0
        onDismissed: root.closeContextMenu()
    }

    MenuList {
        id: contextMenu
        visible: root.contextMenuEntry !== null
        entries: root.contextMenuEntries
        maxHeight: root.height - 16
        // Clamp so the menu never renders past the launcher's own edge.
        x: Math.min(root.contextMenuPos.x, root.width - width - 8)
        y: Math.min(root.contextMenuPos.y, root.height - height - 8)
        onTriggered: root.closeContextMenu()
        onDismissed: root.closeContextMenu()
    }
}
