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

    // Right-click context menu — freedesktop "Desktop Actions" for the app
    // under contextMenuEntry (e.g. Ghostty's "New Window"), positioned at
    // contextMenuPos in this item's own coordinate space. null entry
    // means no menu is open.
    property var contextMenuEntry: null
    property point contextMenuPos: Qt.point(0, 0)
    readonly property var results: Launcher.results
    readonly property bool emojiMode: Launcher.emojiMode

    function refresh() {
        Launcher.search(searchField.text);
        resultList.currentIndex = results.length > 0 ? Math.min(resultList.currentIndex, results.length - 1) : 0;
    }
    function refreshWindows() { Launcher.refreshWindows(); }
    function activateResult(result) { Launcher.activate(result); }
    function copyEmoji(entry) { Launcher.activate({ activation: { kind: "emoji", value: entry.emoji } }); }
    function runAction(action) { Launcher.runDesktopAction(action, root.contextMenuEntry ? root.contextMenuEntry.name : ""); }

    Component.onCompleted: {
        searchField.text = "";
        root.refresh();
        root.refreshWindows();
        searchField.focusInput();
        resultList.currentIndex = 0;
    }

    implicitWidth: contentCol.width
    implicitHeight: contentCol.implicitHeight

    Column {
        id: contentCol
        width: 480
        spacing: 12

        // Search field — prominent, Apple-style — plus a trigger button
        // that pre-fills the "/em " prefix for anyone who won't remember
        // to type it themselves.
        Row {
            width: parent.width
            spacing: 8

            SearchField {
                id: searchField
                width: parent.width - emojiButton.width - parent.spacing
                placeholder: "Search apps, windows, settings…"
                inputPixelSize: Config.fontSize + 2

                onTextChanged: root.refresh()
                onEscapePressed: {
                    if (root.contextMenuEntry) root.contextMenuEntry = null;
                    else IslandNavigation.close();
                }
                onDownPressed: resultList.currentIndex = Math.min(resultList.currentIndex + 1, results.length - 1)
                onUpPressed: resultList.currentIndex = Math.max(resultList.currentIndex - 1, 0)
                onAccepted: {
                    if (results.length === 0) return;
                    const result = results[resultList.currentIndex];
                    root.activateResult(result);
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

        // Results list
        ListView {
            id: resultList
            width: parent.width
            visible: results.length > 0
            height: visible ? Math.min(400, results.length * 52) : 0
            clip: true
            model: results
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
                            if (resultRow.kind !== "app" || !resultRow.entry.actions || resultRow.entry.actions.length === 0) return;
                            const pos = resultMouseArea.mapToItem(root, mouse.x, mouse.y);
                            root.contextMenuPos = pos;
                            root.contextMenuEntry = resultRow.entry;
                            return;
                        }
                        if (resultRow.kind === "emoji") { root.copyEmoji(resultRow.entry); IslandNavigation.close(); }
                        else root.activateResult(resultRow.modelData);
                    }
                }
            }
        }

        // Empty state
        Item {
            visible: results.length === 0 && searchField.text.length > 0
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

    // Right-click context menu — freedesktop Desktop Actions for the app
    // under contextMenuEntry. Kept as its own top-level popup (not nested
    // in the result delegate) so it isn't clipped by the ListView, and
    // positioned in this item's own coordinate space since it's a sibling
    // of contentCol rather than a reparented window-level overlay.
    Scrim {
        active: root.contextMenuEntry !== null
        dimOpacity: 0
        onDismissed: root.contextMenuEntry = null
    }

    Item {
        id: contextMenu
        visible: root.contextMenuEntry !== null
        readonly property var actions: root.contextMenuEntry ? root.contextMenuEntry.actions : []
        width: 200
        height: visible ? menuColumn.implicitHeight + 8 : 0
        // Clamp so the menu never renders past the launcher's own edge.
        x: Math.min(root.contextMenuPos.x, root.width - width - 8)
        y: Math.min(root.contextMenuPos.y, root.height - height - 8)

        PanelBackground {
            anchors.fill: parent
        }

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 2

            Repeater {
                model: contextMenu.actions

                delegate: Rectangle {
                    required property var modelData

                    width: menuColumn.width
                    height: 32
                    radius: 8
                    color: actionHover.hovered ? Colors.surfaceHigh : "transparent"

                    HoverHandler { id: actionHover }

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.runAction(modelData);
                            root.contextMenuEntry = null;
                            IslandNavigation.close();
                        }
                    }
                }
            }
        }
    }
}
