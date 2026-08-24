import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

// Keybind cheatsheet, sourced live from `hyprctl binds -j` — reads each
// bind's `description` field (the { description = "..." } every hl.bind()
// call in binds.lua already carries) rather than duplicating the bindings
// list by hand here.
PanelWindow {
    id: root

    visible: Bridge.keybindsOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:keybinds"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // -1, not 0: ignore the bar's exclusive-zone reservation so this
    // full-screen surface actually reaches the true top edge instead of
    // being shrunk away from it. Same fix as Wallpaper.qml.
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
        mouse_down: "Scroll ↓", mouse_up: "Scroll ↑",
        "mouse:272": "Left Click", "mouse:273": "Right Click",
        Print: "Print Screen",
        XF86AudioRaiseVolume: "Volume Up", XF86AudioLowerVolume: "Volume Down",
        XF86AudioMute: "Mute", XF86AudioMicMute: "Mic Mute",
        XF86MonBrightnessUp: "Brightness Up", XF86MonBrightnessDown: "Brightness Down",
        XF86AudioNext: "Next Track", XF86AudioPrev: "Prev Track",
        XF86AudioPlay: "Play/Pause", XF86AudioPause: "Play/Pause"
    })

    function keyLabel(key) {
        if (root.keyLabels[key]) return root.keyLabels[key];
        return key.length === 1 ? key.toUpperCase() : key;
    }

    function comboLabel(bind) {
        const mods = root.modOrder.filter(m => (bind.modmask & m.bit) !== 0).map(m => m.label);
        mods.push(root.keyLabel(bind.key));
        return mods.join(" + ");
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.visible ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Config.animMedium } }

        MouseArea {
            anchors.fill: parent
            onClicked: Bridge.closeKeybinds()
        }
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: Bridge.closeKeybinds()

        PanelBackground {
            id: card
            width: 640
            height: Math.min(620, root.height * 0.82)
            anchors.centerIn: parent

            MouseArea {
                // Swallows clicks so they don't fall through to the
                // full-screen backdrop behind this card and close it.
                anchors.fill: parent
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 8

                    MaterialIcon {
                        icon: "keyboard"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Keybinds"
                        font.bold: true
                        font.pixelSize: Config.fontSize + 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 40
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
                            font.pixelSize: Config.fontSize
                            clip: true

                            Keys.onEscapePressed: Bridge.closeKeybinds()

                            StyledText {
                                visible: searchInput.text.length === 0
                                text: "Filter keybinds…"
                                opacity: 0.5
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Flickable {
                    id: flick
                    width: parent.width
                    height: parent.height - 92
                    clip: true
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: list
                        width: flick.width
                        spacing: 2

                        Repeater {
                            model: root.filtered

                            Rectangle {
                                required property var modelData
                                required property int index

                                width: list.width
                                height: 36
                                radius: Colors.radiusSmall
                                color: index % 2 === 0 ? "transparent" : Colors.surfaceHigh
                                opacity: index % 2 === 0 ? 1 : 0.5

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 12

                                    Rectangle {
                                        width: 180
                                        height: 26
                                        radius: Colors.radiusSmall
                                        color: Colors.surface
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            anchors.centerIn: parent
                                            anchors.margins: 6
                                            text: root.comboLabel(modelData)
                                            color: Colors.accent
                                            font.pixelSize: Config.fontSize - 2
                                            font.family: Config.monoFontFamily
                                            elide: Text.ElideRight
                                        }
                                    }

                                    StyledText {
                                        width: parent.width - 192
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.description
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: root.filtered.length === 0
                            width: list.width
                            horizontalAlignment: Text.AlignHCenter
                            opacity: 0.5
                            text: "No matching binds"
                        }
                    }
                }
            }
        }
    }
}
