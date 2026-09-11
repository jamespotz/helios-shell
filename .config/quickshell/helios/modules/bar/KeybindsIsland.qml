import QtQuick
import Quickshell.Io
import "../../services"
import "../../components"

// Apple Keyboard Shortcuts-style cheatsheet — search filtering, grouped by
// modifier, sourced live from `hyprctl binds -j`.
Item {
    id: root

    readonly property int listHeight: 380

    property var entries: []
    readonly property bool searchFocused: searchField.inputActiveFocus
    property int selectedIndex: filtered.length > 0 ? 0 : -1

    function focusSearch() { searchField.focusInput(); }

    function moveSelection(delta) {
        if (root.filtered.length === 0) return;
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex + delta, root.filtered.length - 1));
        const rowTop = root.selectedIndex * 44;
        const rowBottom = rowTop + 40;
        if (rowTop < flick.contentY) flick.contentY = rowTop;
        else if (rowBottom > flick.contentY + flick.height)
            flick.contentY = Math.min(rowBottom - flick.height, Math.max(0, flick.contentHeight - flick.height));
    }

    readonly property var filtered: {
        const q = searchField.text.trim().toLowerCase();
        if (!q) return entries;
        return entries.filter(b => (b.description || "").toLowerCase().includes(q)
            || root.comboLabel(b).toLowerCase().includes(q));
    }

    onFilteredChanged: selectedIndex = filtered.length > 0 ? 0 : -1

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

    Component.onCompleted: {
        bindsProc.running = true;
        focusSearchTimer.restart();
    }

    // Bar establishes its Hyprland keyboard grab shortly after loading.
    // Focus after that handoff so the grab cannot leave focus on the panel.
    Timer {
        id: focusSearchTimer
        interval: 120
        onTriggered: root.focusSearch()
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
        "mouse:272": "Click", "mouse:273": "Right Click",
        Print: "PrtSc",
        XF86AudioRaiseVolume: "Vol ↑", XF86AudioLowerVolume: "Vol ↓",
        XF86AudioMute: "Mute", XF86AudioMicMute: "Mic Mute",
        XF86MonBrightnessUp: "Bright ↑", XF86MonBrightnessDown: "Bright ↓",
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

    implicitWidth: col.width
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: 480
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
        SearchField {
            id: searchField
            width: parent.width
            placeholder: "Filter shortcuts…"
            onEscapePressed: IslandNavigation.close()
            onUpPressed: root.moveSelection(-1)
            onDownPressed: root.moveSelection(1)
        }

        // Bind list
        Item {
            width: parent.width
            height: root.listHeight

            Flickable {
                id: flick
                anchors.fill: parent
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
                        color: index === root.selectedIndex ? Colors.accent
                            : bindHover.hovered ? Colors.surfaceHigh : "transparent"
                        opacity: index === root.selectedIndex ? 1 : bindHover.hovered ? 0.6 : 1

                        Behavior on color { ColorAnimation { duration: Config.animFast } }

                        HoverHandler { id: bindHover }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Key combo — individual pill badges
                            Row {
                                width: 200
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
                                width: parent.width - 200 - 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.description
                                elide: Text.ElideRight
                                font.pixelSize: Config.fontSize - 1
                                color: index === root.selectedIndex ? Colors.accentText : Colors.text
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
            }

            ScrollIndicator { target: flick }
        }
    }
}
