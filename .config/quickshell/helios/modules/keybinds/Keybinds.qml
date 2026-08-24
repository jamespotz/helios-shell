import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

// Apple Keyboard Shortcuts-style cheatsheet — clean card layout with
// pill-shaped key badges, search filtering, and grouped by modifier.
// Sourced live from `hyprctl binds -j`.
PanelWindow {
    id: root

    visible: Bridge.keybindsOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:keybinds"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    property var entries: []

    readonly property var filtered: {
        const q = searchInput.text.trim().toLowerCase();
        if (!q) return entries;
        return entries.filter(b => (b.description || "").toLowerCase().includes(q)
            || root.comboLabel(b).toLowerCase().includes(q));
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.entries = JSON.parse(text).filter(b => b.description && b.description.length > 0);
                } catch (e) {
                    root.entries = [];
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            bindsProc.running = false;
            bindsProc.running = true;
            searchInput.forceActiveFocus();
        }
    }

    readonly property var modOrder: [
        { bit: 64, label: "Super" },
        { bit: 4, label: "Ctrl" },
        { bit: 8, label: "Alt" },
        { bit: 1, label: "Shift" },
        { bit: 32, label: "Mod3" },
        { bit: 16, label: "Mod2" },
        { bit: 128, label: "Mod5" }
    ]

    readonly property var keyLabels: ({
        equal: "=", minus: "-", comma: ",", space: "Space",
        mouse_down: "Scroll \u2193", mouse_up: "Scroll \u2191",
        "mouse:272": "Click", "mouse:273": "Right Click",
        Print: "PrtSc",
        XF86AudioRaiseVolume: "Vol \u2191", XF86AudioLowerVolume: "Vol \u2193",
        XF86AudioMute: "Mute", XF86AudioMicMute: "Mic Mute",
        XF86MonBrightnessUp: "Bright \u2191", XF86MonBrightnessDown: "Bright \u2193",
        XF86AudioNext: "Next", XF86AudioPrev: "Prev",
        XF86AudioPlay: "Play", XF86AudioPause: "Pause"
    })

    function keyLabel(key) {
        if (root.keyLabels[key]) return root.keyLabels[key];
        return key.length === 1 ? key.toUpperCase() : key;
    }

    function modLabels(bind) {
        return root.modOrder.filter(m => (bind.modmask & m.bit) !== 0).map(m => m.label);
    }

    function comboLabel(bind) {
        const mods = root.modLabels(bind);
        mods.push(root.keyLabel(bind.key));
        return mods.join(" + ");
    }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.visible ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: Bridge.closeKeybinds()
        }
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: Bridge.closeKeybinds()

        // Main card
        Rectangle {
            id: card
            width: 680
            height: Math.min(640, root.height * 0.8)
            anchors.centerIn: parent
            radius: 16
            color: Colors.surface
            opacity: Colors.panelOpacity

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 0.5
                border.color: Qt.rgba(1, 1, 1, 0.08)
            }

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                // Header
                Row {
                    width: parent.width
                    spacing: 10

                    MaterialIcon {
                        icon: "keyboard"
                        font.pixelSize: 22
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Keyboard Shortcuts"
                        font.weight: Font.Bold
                        font.pixelSize: Config.fontSize + 4
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: parent.width - parent.children[0].width - parent.children[1].implicitWidth - countLabel.implicitWidth - 30; height: 1 }

                    StyledText {
                        id: countLabel
                        text: root.filtered.length + " binds"
                        font.pixelSize: Config.fontSize - 1
                        color: Colors.subtext
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Search
                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 12
                    color: Colors.surfaceHigh

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        MaterialIcon {
                            icon: "search"
                            font.pixelSize: 18
                            color: Colors.subtext
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextInput {
                            id: searchInput
                            width: parent.width - 28 - 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Colors.text
                            font.family: Config.fontFamily
                            font.pixelSize: Config.fontSize
                            clip: true

                            Keys.onEscapePressed: Bridge.closeKeybinds()

                            StyledText {
                                visible: searchInput.text.length === 0
                                text: "Filter shortcuts…"
                                color: Colors.subtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Bind list
                Flickable {
                    id: flick
                    width: parent.width
                    height: parent.height - 110
                    clip: true
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: list
                        width: flick.width
                        spacing: 4

                        Repeater {
                            model: root.filtered

                            Rectangle {
                                required property var modelData
                                required property int index

                                width: list.width
                                height: 40
                                radius: 10
                                color: bindHover.hovered ? Colors.surfaceHigh : "transparent"
                                opacity: bindHover.hovered ? 0.6 : 1

                                Behavior on color { ColorAnimation { duration: Config.animFast } }

                                HoverHandler { id: bindHover }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Key combo — individual pill badges
                                    Row {
                                        width: 220
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Repeater {
                                            model: {
                                                const mods = root.modLabels(modelData);
                                                mods.push(root.keyLabel(modelData.key));
                                                return mods;
                                            }

                                            Rectangle {
                                                required property string modelData
                                                width: keyText.implicitWidth + 14
                                                height: 24
                                                radius: 6
                                                color: Colors.surfaceHigh
                                                border.width: 0.5
                                                border.color: Colors.overlay
                                                opacity: 0.8

                                                StyledText {
                                                    id: keyText
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    font.pixelSize: Config.fontSize - 2
                                                    font.family: Config.monoFontFamily
                                                    font.weight: Font.Medium
                                                    color: Colors.text
                                                }
                                            }
                                        }
                                    }

                                    // Description
                                    StyledText {
                                        width: parent.width - 220 - 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.description
                                        elide: Text.ElideRight
                                        font.pixelSize: Config.fontSize - 1
                                        color: Colors.text
                                    }
                                }
                            }
                        }

                        // Empty state
                        Item {
                            visible: root.filtered.length === 0
                            width: list.width
                            height: 80

                            Column {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIcon { icon: "search_off"; font.pixelSize: 28; color: Colors.overlay; anchors.horizontalCenter: parent.horizontalCenter }
                                StyledText { text: "No matching shortcuts"; color: Colors.subtext; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }

                    // Scroll indicator
                    Rectangle {
                        visible: flick.contentHeight > flick.height
                        width: 3
                        radius: 1.5
                        color: Colors.accent
                        opacity: 0.5
                        anchors.right: parent.right
                        y: flick.contentHeight > 0 ? (flick.contentY / flick.contentHeight) * flick.height : 0
                        height: flick.contentHeight > 0 ? Math.max(20, (flick.height / flick.contentHeight) * flick.height) : flick.height
                    }
                }
            }
        }
    }
}
