import QtQuick
import "../../services"
import "../../components"

// Focus mode presets — each preset is a saved combination of DND,
// caffeine, night light, power profile, and apps to launch, applied
// together with one tap. List view + inline editor, same shape as other
// settings tabs (see NightLightIsland.qml) but for a user-editable collection
// rather than a fixed set of controls.
Item {
    id: root

    property string editingId: ""

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 8

    readonly property var powerOptions: [
        { value: "", label: "Off", icon: "" },
        { value: "saver", label: "Saver", icon: "eco" },
        { value: "balanced", label: "Balanced", icon: "balance" },
        { value: "performance", label: "Perf.", icon: "bolt" }
    ]

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 10

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "do_not_disturb_on"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Focus Modes"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        // ─── Preset list ───────────────────────────────────────────────
        Repeater {
            model: FocusModes.presets

            delegate: Column {
                id: row
                required property var modelData
                width: col.width
                spacing: 8

                readonly property bool active: FocusModes.activeId === modelData.id
                readonly property bool isEditing: root.editingId === modelData.id

                Rectangle {
                    width: parent.width
                    height: 52
                    radius: Colors.radiusSmall
                    color: row.active ? Colors.accent : (cardHover.hovered ? Colors.surfaceHigh : Colors.surface)

                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    HoverHandler { id: cardHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10

                        MaterialIcon {
                            icon: row.modelData.icon || "center_focus_strong"
                            font.pixelSize: 18
                            color: row.active ? Colors.accentText : Colors.subtext
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            width: parent.width - 18 - 10 - editBtn.width - 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name
                            font.weight: Font.Medium
                            color: row.active ? Colors.accentText : Colors.text
                            elide: Text.ElideRight
                        }

                        IconButton {
                            id: editBtn
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "edit"
                            iconSize: 14
                            iconColor: row.active ? Colors.accentText : Colors.subtext
                            onClicked: root.editingId = row.isEditing ? "" : row.modelData.id
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: editBtn.width + 16
                        cursorShape: Qt.PointingHandCursor
                        onClicked: FocusModes.toggle(row.modelData)
                    }
                }

                // ─── Inline editor ───────────────────────────────────────
                // Text fields hold a local draft synced from modelData and
                // commit on Return/blur rather than live per keystroke —
                // updatePreset() replaces the whole presets array, which
                // rebuilds every delegate here (plain-array Repeater has no
                // incremental diffing), so a live-commit field would lose
                // input focus after every character. See IslandSettings.qml's
                // weatherDraft for the same tradeoff on the same kind of field.
                Column {
                    id: editor
                    width: parent.width
                    visible: row.isEditing
                    spacing: 10
                    leftPadding: 4
                    rightPadding: 4

                    property string nameDraft: row.modelData.name
                    property string appsDraft: (row.modelData.apps || []).join(", ")

                    Row {
                        width: parent.width - 8
                        spacing: 8

                        StyledText { text: "Name"; width: 90; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }

                        Rectangle {
                            width: parent.width - 90 - 8
                            height: 32
                            radius: height / 2
                            color: Colors.surface

                            TextInput {
                                id: nameInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                color: Colors.text
                                font.family: Config.fontFamily
                                font.pixelSize: Config.fontSize - 1
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                text: editor.nameDraft

                                onTextChanged: editor.nameDraft = text
                                Keys.onReturnPressed: FocusModes.updatePreset(row.modelData.id, { name: editor.nameDraft })
                                onActiveFocusChanged: if (!activeFocus) FocusModes.updatePreset(row.modelData.id, { name: editor.nameDraft })
                            }
                        }
                    }

                    Row {
                        width: parent.width - 8
                        spacing: 8
                        StyledText { text: "Do Not Disturb"; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 8 - dndToggle.width }
                        Toggle { id: dndToggle; checked: !!row.modelData.dnd; onToggled: v => FocusModes.updatePreset(row.modelData.id, { dnd: v }) }
                    }

                    Row {
                        width: parent.width - 8
                        spacing: 8
                        StyledText { text: "Caffeine (keep awake)"; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 8 - caffeineToggle.width }
                        Toggle { id: caffeineToggle; checked: !!row.modelData.caffeine; onToggled: v => FocusModes.updatePreset(row.modelData.id, { caffeine: v }) }
                    }

                    Row {
                        width: parent.width - 8
                        spacing: 8
                        StyledText { text: "Night Light"; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 8 - nightToggle.width }
                        Toggle { id: nightToggle; checked: !!row.modelData.nightLight; onToggled: v => FocusModes.updatePreset(row.modelData.id, { nightLight: v }) }
                    }

                    Column {
                        width: parent.width - 8
                        spacing: 6
                        StyledText { text: "Power Profile"; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
                        SegmentedControl {
                            width: parent.width
                            model: root.powerOptions
                            currentValue: row.modelData.powerProfile || ""
                            onActivated: value => FocusModes.updatePreset(row.modelData.id, { powerProfile: value })
                        }
                    }

                    Column {
                        id: appsRow
                        width: parent.width - 8
                        spacing: 6
                        StyledText { text: "Launch apps (comma-separated)"; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }

                        function commitApps() {
                            FocusModes.updatePreset(row.modelData.id, {
                                apps: editor.appsDraft.split(",").map(s => s.trim()).filter(s => s.length > 0)
                            });
                        }

                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: height / 2
                            color: Colors.surface

                            TextInput {
                                id: appsInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                color: Colors.text
                                font.family: Config.fontFamily
                                font.pixelSize: Config.fontSize - 1
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                text: editor.appsDraft

                                onTextChanged: editor.appsDraft = text
                                Keys.onReturnPressed: appsRow.commitApps()
                                onActiveFocusChanged: if (!activeFocus) appsRow.commitApps()

                                StyledText {
                                    visible: appsInput.text.length === 0
                                    text: "e.g. Ghostty, Zed"
                                    opacity: 0.5
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    PrimaryButton {
                        width: parent.width - 8
                        text: "Delete Preset"
                        icon: "delete"
                        tint: Colors.danger
                        onClicked: { root.editingId = ""; FocusModes.removePreset(row.modelData.id); }
                    }
                }
            }
        }

        // ─── New preset ────────────────────────────────────────────────
        PrimaryButton {
            width: parent.width
            text: "New Focus Mode"
            icon: "add"
            onClicked: {
                const preset = FocusModes.addPreset();
                root.editingId = preset.id;
            }
        }
    }
}
