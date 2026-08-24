import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

PanelWindow {
    id: launcher

    visible: Bridge.launcherOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:launcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // -1, not 0: makes this surface ignore *other* surfaces' exclusive-zone
    // reservations (the bar's reserved top strip) instead of being shrunk
    // away from them, so the dim backdrop actually reaches the true screen
    // edges. Same fix as Wallpaper.qml, same underlying cause.
    exclusiveZone: -1

    IpcHandler {
        target: "launcher"
        function toggle() { Bridge.toggleLauncher() }
        function open() { Bridge.launcherOpen = true }
        function close() { Bridge.launcherOpen = false }
    }

    property var results: []

    // DesktopEntry.keywords (and ExtraApps entries' own keywords) come through
    // as a list, not a string — calling .toLowerCase() on it directly threw
    // for every app that had more than one keyword, which aborted the whole
    // .filter() mid-way and left `results` stuck on a stale/empty value. That
    // was the actual cause of "apps missing" (flatpak entries included) — the
    // affected apps were already being found, just never rendered.
    function matchesKeywords(entry, query) {
        const kw = entry.keywords;
        if (!kw || kw.length === 0) return false;
        if (typeof kw.some === "function") return kw.some(k => k.toLowerCase().includes(query));
        return String(kw).toLowerCase().includes(query);
    }

    function refresh() {
        const query = searchInput.text.trim().toLowerCase();
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

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            refresh();
            searchInput.forceActiveFocus();
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

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: launcher.visible ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: Config.animMedium } }

        MouseArea {
            anchors.fill: parent
            onClicked: Bridge.launcherOpen = false
        }
    }

    PanelBackground {
        id: card
        width: 480
        height: 440
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.18

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Rectangle {
                width: parent.width
                height: 42
                radius: Colors.radiusSmall
                color: Colors.surfaceHigh

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialIcon {
                        icon: "search"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 32
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        font.family: Config.fontFamily
                        font.pixelSize: Config.fontSize + 1
                        focus: true
                        clip: true

                        Keys.onEscapePressed: Bridge.launcherOpen = false
                        Keys.onDownPressed: resultList.currentIndex = Math.min(resultList.currentIndex + 1, results.length - 1)
                        Keys.onUpPressed: resultList.currentIndex = Math.max(resultList.currentIndex - 1, 0)
                        Keys.onReturnPressed: {
                            if (results.length > 0) {
                                results[resultList.currentIndex].execute();
                                Bridge.launcherOpen = false;
                            }
                        }
                        onTextChanged: launcher.refresh()

                        StyledText {
                            visible: searchInput.text.length === 0
                            text: "Search apps…"
                            opacity: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            ListView {
                id: resultList
                width: parent.width
                height: parent.height - 52
                clip: true
                model: results
                spacing: 2
                currentIndex: 0

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: resultList.width
                    height: 46
                    radius: Colors.radiusSmall
                    color: index === resultList.currentIndex ? Colors.surfaceHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: resultHover.hovered && index !== resultList.currentIndex ? 0.15 : 0
                    }

                    HoverHandler { id: resultHover }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        Image {
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(modelData.icon, true)
                            fillMode: Image.PreserveAspectFit
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: modelData.name; font.bold: true }
                            StyledText {
                                visible: !!modelData.genericName
                                text: modelData.genericName
                                opacity: 0.6
                                font.pixelSize: Config.fontSize - 2
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.execute();
                            Bridge.launcherOpen = false;
                        }
                    }
                }
            }
        }
    }
}
