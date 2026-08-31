import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

// Apple Spotlight-inspired launcher — centered floating card with a
// prominent search field, clean result rows with rounded app icons,
// and smooth keyboard navigation. Terminal apps (btop, nvim, etc.)
// are automatically spawned inside Config.terminal.
PanelWindow {
    id: launcher

    visible: Bridge.launcherOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:launcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    IpcHandler {
        target: "launcher"
        function toggle() { Bridge.toggleLauncher() }
        function open() { Bridge.launcherOpen = true }
        function close() { Bridge.launcherOpen = false }
    }

    property var results: []
    // Set by refresh() whenever the query is a "/em[oji] <term>" search —
    // switches the results delegate from app rows to emoji rows and the
    // accept/click action from launching to copying.
    property bool emojiMode: false

    // Right-click context menu — freedesktop "Desktop Actions" for the app
    // under contextMenuEntry (e.g. Ghostty's "New Window"), positioned at
    // contextMenuPos in the launcher window's own coordinate space. null
    // entry means no menu is open.
    property var contextMenuEntry: null
    property point contextMenuPos: Qt.point(0, 0)

    // --- Launch frequency tracking ------------------------------------------
    // Drives the "most used" ranking in refresh() below — persisted so it
    // survives restarts, same FileView pattern as Activity.qml's app-usage
    // log. Keyed by entry.name since that's already the dedup key refresh()
    // uses to merge DesktopEntries + ExtraApps.
    property var launchCounts: ({})

    function countFor(name) { return launcher.launchCounts[name] || 0; }
    function recordLaunch(name) {
        if (!name) return;
        launcher.launchCounts = Object.assign({}, launcher.launchCounts, { [name]: launcher.countFor(name) + 1 });
        launchCountsFile.setText(JSON.stringify(launcher.launchCounts));
    }

    property FileView launchCountsFile: FileView {
        path: Quickshell.statePath("launcher-app-usage.json")
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(launchCountsFile.text());
                if (parsed && typeof parsed === "object") launcher.launchCounts = parsed;
            } catch (e) {
                // First run / empty file — start with no usage history.
            }
        }
    }

    function matchesKeywords(entry, query) {
        const kw = entry.keywords;
        if (!kw || kw.length === 0) return false;
        if (typeof kw.some === "function") return kw.some(k => k.toLowerCase().includes(query));
        return String(kw).toLowerCase().includes(query);
    }

    // Relevance tiers so e.g. "fire" ranks Firefox (name match) above some
    // unrelated app whose keywords merely happen to contain "fire". Ties
    // within a tier fall back to launch frequency — see refresh() below.
    function matchScore(entry, query) {
        const name = entry.name.toLowerCase();
        if (name === query) return 4;
        if (name.startsWith(query)) return 3;
        if (name.includes(query)) return 2;
        if ((entry.genericName || "").toLowerCase().includes(query)) return 1;
        if (launcher.matchesKeywords(entry, query)) return 1;
        return 0;
    }

    // Deduped app list, independent of the search query — hoisted out of
    // refresh() so it only recomputes when DesktopEntries/ExtraApps actually
    // change instead of on every keystroke (refresh() used to redo this
    // filter+concat+dedup on every single character typed).
    readonly property var allApps: {
        const seen = new Set();
        return DesktopEntries.applications.values.filter(e => !e.noDisplay)
            .concat(ExtraApps.list)
            .filter(e => {
                if (seen.has(e.name)) return false;
                seen.add(e.name);
                return true;
            });
    }

    function refresh() {
        const raw = searchField.text.trim();
        // "/em" or "/emoji", optionally followed by a search term.
        const emojiPrefix = raw.match(/^\/em(?:oji)?(?:\s+(.*))?$/i);
        let newResults;
        if (emojiPrefix) {
            launcher.emojiMode = true;
            newResults = Emoji.search(emojiPrefix[1] || "", 9);
        } else {
            launcher.emojiMode = false;

            const query = raw.toLowerCase();
            const all = launcher.allApps;
            if (!query) {
                // No query: lead with whatever's actually used most (Spotlight-
                // style "frequently used" ranking) instead of DesktopEntries'
                // arbitrary filesystem-scan order.
                newResults = all.slice().sort((a, b) => {
                    return launcher.countFor(b.name) - launcher.countFor(a.name) || a.name.localeCompare(b.name);
                }).slice(0, 9);
            } else {
                newResults = all.map(e => ({ entry: e, score: launcher.matchScore(e, query) }))
                    .filter(m => m.score > 0)
                    .sort((a, b) => {
                        return b.score - a.score
                            || launcher.countFor(b.entry.name) - launcher.countFor(a.entry.name)
                            || a.entry.name.localeCompare(b.entry.name);
                    })
                    .map(m => m.entry)
                    .slice(0, 9);
            }
        }
        results = newResults;
        // Results reorder/shrink on every keystroke — clamp the arrow-key
        // selection so it can't point past the new array (was: stale index
        // survived a narrowing refresh, so Enter indexed out of bounds).
        resultList.currentIndex = results.length > 0 ? Math.min(resultList.currentIndex, results.length - 1) : 0;
    }

    // Launch an app — ExtraApps entries already handle terminal wrapping in
    // their own execute(); AppLaunch.launch() does the same for a plain
    // DesktopEntry, whose native execute() does not spawn a terminal even
    // when runInTerminal is true.
    function launchApp(entry) {
        launcher.recordLaunch(entry.name);
        AppLaunch.launch(entry);
    }

    // Runs a Desktop Action (the context menu's entries, e.g. Ghostty's
    // "New Window") the same defensive way launchApp() runs the main entry
    // — DesktopAction.execute() silently did nothing when tested live here
    // (same gap as DesktopEntry.execute() noted above), while manually
    // spawning its parsed command works.
    function runAction(action) {
        // A Desktop Action (e.g. "New Window") still launches the app it
        // belongs to, so it counts toward that app's frequency too.
        launcher.recordLaunch(launcher.contextMenuEntry ? launcher.contextMenuEntry.name : "");
        const cmd = action.command || [];
        if (cmd.length > 0) {
            Quickshell.execDetached(cmd);
        } else {
            const exec = (action.execString || "").replace(/%[fFuUdDnNickvm]/g, "").trim();
            if (exec) Quickshell.execDetached(["sh", "-c", exec]);
        }
    }

    // Copies the emoji glyph to the clipboard — Wayland has no portable way
    // to inject keystrokes into whatever was focused before the launcher
    // (that's what typing would require), so copy-then-paste is the actual
    // reliable path, same as every other emoji picker.
    function copyEmoji(entry) {
        emojiCopier.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", entry.emoji];
        emojiCopier.running = false;
        emojiCopier.running = true;
    }

    Process { id: emojiCopier }

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            refresh();
            searchField.focusInput();
            resultList.currentIndex = 0;
        } else {
            contextMenuEntry = null;
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { if (launcher.visible) launcher.refresh() }
    }

    Connections {
        target: ExtraApps
        function onListChanged() { if (launcher.visible) launcher.refresh() }
    }

    Scrim {
        active: launcher.visible
        dimOpacity: 0.4
        onDismissed: Bridge.launcherOpen = false
    }

    // Main card — Apple Spotlight style
    Item {
        id: card
        width: 540
        height: contentCol.implicitHeight + 32
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16

        Behavior on height { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

        PanelBackground {
            anchors.fill: parent
        }

        Column {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
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
                    placeholder: "Search apps…"
                    inputPixelSize: Config.fontSize + 2

                    onTextChanged: launcher.refresh()
                    onEscapePressed: {
                        if (launcher.contextMenuEntry) launcher.contextMenuEntry = null;
                        else Bridge.launcherOpen = false;
                    }
                    onDownPressed: resultList.currentIndex = Math.min(resultList.currentIndex + 1, results.length - 1)
                    onUpPressed: resultList.currentIndex = Math.max(resultList.currentIndex - 1, 0)
                    onAccepted: {
                        if (results.length === 0) return;
                        const entry = results[resultList.currentIndex];
                        if (launcher.emojiMode) launcher.copyEmoji(entry);
                        else launcher.launchApp(entry);
                        Bridge.launcherOpen = false;
                    }
                }

                IconButton {
                    id: emojiButton
                    icon: "add_reaction"
                    iconSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                    active: launcher.emojiMode
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
                    required property var modelData
                    required property int index

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

                        // App icon — rounded square
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
                                visible: !launcher.emojiMode
                                source: launcher.emojiMode ? "" : Quickshell.iconPath(modelData.icon, true)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            StyledText {
                                anchors.centerIn: parent
                                visible: launcher.emojiMode
                                text: launcher.emojiMode ? modelData.emoji : ""
                                font.pixelSize: 19
                            }
                        }

                        // Name + description (apps: generic name; emoji: category)
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36 - 12 - 10 - termBadge.width - 10
                            spacing: 1

                            StyledText {
                                text: modelData.name
                                font.weight: Font.Medium
                                color: index === resultList.currentIndex ? Colors.accentText : Colors.text
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            StyledText {
                                readonly property string subtitle: modelData.genericName || modelData.category || ""
                                visible: !!subtitle
                                text: subtitle
                                font.pixelSize: Config.fontSize - 2
                                color: index === resultList.currentIndex ? Qt.rgba(Colors.accentText.r, Colors.accentText.g, Colors.accentText.b, 0.7) : Colors.subtext
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }

                        // Terminal badge — shows when app needs terminal
                        Rectangle {
                            id: termBadge
                            visible: modelData.runInTerminal === true
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
                                if (launcher.emojiMode || !modelData.actions || modelData.actions.length === 0) return;
                                const pos = resultMouseArea.mapToItem(QsWindow.contentItem, mouse.x, mouse.y);
                                launcher.contextMenuPos = pos;
                                launcher.contextMenuEntry = modelData;
                                return;
                            }
                            if (launcher.emojiMode) launcher.copyEmoji(modelData);
                            else launcher.launchApp(modelData);
                            Bridge.launcherOpen = false;
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
                    StyledText { text: launcher.emojiMode ? "No matching emoji" : "No results"; color: Colors.subtext; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
        }
    }

    // Right-click context menu — freedesktop Desktop Actions for the app
    // under contextMenuEntry. Kept as its own top-level popup (not nested
    // in the result delegate) so it isn't clipped by the ListView/card and
    // can be positioned at the click point in window coordinates.
    Scrim {
        active: launcher.contextMenuEntry !== null
        dimOpacity: 0
        onDismissed: launcher.contextMenuEntry = null
    }

    Item {
        id: contextMenu
        visible: launcher.contextMenuEntry !== null
        readonly property var actions: launcher.contextMenuEntry ? launcher.contextMenuEntry.actions : []
        width: 200
        height: visible ? menuColumn.implicitHeight + 8 : 0
        // Clamp so the menu never renders past the right/bottom screen edge.
        x: Math.min(launcher.contextMenuPos.x, launcher.width - width - 8)
        y: Math.min(launcher.contextMenuPos.y, launcher.height - height - 8)

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
                            launcher.runAction(modelData);
                            launcher.contextMenuEntry = null;
                            Bridge.launcherOpen = false;
                        }
                    }
                }
            }
        }
    }
}
