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

    function matchesKeywords(entry, query) {
        const kw = entry.keywords;
        if (!kw || kw.length === 0) return false;
        if (typeof kw.some === "function") return kw.some(k => k.toLowerCase().includes(query));
        return String(kw).toLowerCase().includes(query);
    }

    function refresh() {
        const raw = searchField.text.trim();
        // "/em" or "/emoji", optionally followed by a search term.
        const emojiPrefix = raw.match(/^\/em(?:oji)?(?:\s+(.*))?$/i);
        if (emojiPrefix) {
            launcher.emojiMode = true;
            results = Emoji.search(emojiPrefix[1] || "", 9);
            return;
        }
        launcher.emojiMode = false;

        const query = raw.toLowerCase();
        const seen = new Set();
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay)
            .concat(ExtraApps.list)
            .filter(e => {
                if (seen.has(e.name)) return false;
                seen.add(e.name);
                return true;
            });
        if (!query) {
            results = all.slice(0, 9);
            return;
        }
        results = all.filter(e => {
            return e.name.toLowerCase().includes(query)
                || (e.genericName && e.genericName.toLowerCase().includes(query))
                || launcher.matchesKeywords(e, query);
        }).slice(0, 9);
    }

    // Launch an app — wraps terminal apps (btop, nvim, etc.) in the
    // configured terminal emulator. ExtraApps entries already handle this
    // in their own execute(), but Quickshell's native DesktopEntry.execute()
    // does NOT spawn a terminal even when runInTerminal is true.
    function launchApp(entry) {
        if (entry.runInTerminal) {
            // entry.command is the parsed Exec as a list
            const cmd = entry.command || [];
            if (cmd.length > 0) {
                const args = [Config.terminal, "-e"].concat(cmd);
                Quickshell.execDetached(args);
            } else {
                // Fallback: try executing the raw exec string
                const exec = (entry.execString || "").replace(/%[fFuUdDnNickvm]/g, "").trim();
                if (exec) Quickshell.execDetached([Config.terminal, "-e", "sh", "-c", exec]);
            }
        } else {
            entry.execute();
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
                    onEscapePressed: Bridge.launcherOpen = false
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
                    color: index === resultList.currentIndex ? Colors.accent : "transparent"

                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    // Hover overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: resultHover.hovered && index !== resultList.currentIndex ? 0.3 : 0
                        Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                    }

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
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
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
}
