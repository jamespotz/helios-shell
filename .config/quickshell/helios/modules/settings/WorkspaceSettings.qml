import QtQuick
import "../../services"
import "../../components"

// Settings > Workspaces — how the island's workspace indicator looks, and
// per-workspace icons for the "custom" style.
Item {
    id: root

    // Workspace whose icon picker is open (0 = none) — one at a time.
    property int editingWorkspace: 0
    readonly property var workspaceIconSuggestions: [
        "terminal", "code", "language", "forum", "mail", "music_note", "movie", "sports_esports",
        "folder", "edit_note", "brush", "photo_camera", "work", "home", "school", "description"
    ]

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        Row {
            spacing: 8
            bottomPadding: 10
            MaterialIcon { icon: "grid_view"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Workspaces"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        SettingsCard {
            OptionChoice {
                target: Config
                option: "workspaceIndicatorStyle"
                icon: "grid_view"
                label: "Indicator"
                last: Config.workspaceIndicatorStyle === "dots"
                choices: [
                    { value: "dots", label: "Dots" },
                    { value: "numbers", label: "Numbers" },
                    { value: "custom", label: "Custom" }
                ]
            }
            // Only meaningful for glyph styles — dots always show every workspace.
            OptionToggle {
                visible: Config.workspaceIndicatorStyle !== "dots"
                target: Config
                option: "showAllWorkspaces"
                icon: "view_week"
                label: "Show all workspaces"
                last: true
            }
        }

        // Per-workspace icons — one row per workspace, tap to pick.
        SettingsCard {
            visible: Config.workspaceIndicatorStyle === "custom"

            Repeater {
                model: 10

                Column {
                    id: wsRow
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property string icon: Config.workspaceIcons[wsId] || ""
                    readonly property bool editing: root.editingWorkspace === wsId
                    property string draft: icon

                    width: parent.width

                    Item {
                        id: wsHeader
                        width: parent.width
                        height: 40
                        activeFocusOnTab: true

                        function toggle() { root.editingWorkspace = wsRow.editing ? 0 : wsRow.wsId; }
                        Keys.onReturnPressed: toggle()
                        Keys.onSpacePressed: toggle()

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Colors.radiusSmall
                            color: Colors.overlay
                            opacity: wsHeaderHover.hovered ? 0.12 : 0
                            Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            MaterialIcon {
                                icon: wsRow.icon || (wsRow.wsId <= 9 ? "counter_" + wsRow.wsId : "tag")
                                font.pixelSize: 16
                                color: wsRow.icon ? Colors.accent : Colors.text
                                opacity: wsRow.icon ? 1 : 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText { text: "Workspace " + wsRow.wsId; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            StyledText {
                                text: wsRow.icon || "Default"
                                opacity: 0.5
                                font.pixelSize: Config.fontSize - 2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            MaterialIcon {
                                icon: wsRow.editing ? "expand_less" : "chevron_right"
                                font.pixelSize: 16
                                opacity: 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Focus ring — keyboard-navigation feedback
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Colors.radiusLarge - 2
                            color: "transparent"
                            border.width: 2
                            border.color: Colors.accent
                            visible: wsHeader.activeFocus
                        }

                        HoverHandler { id: wsHeaderHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wsHeader.toggle()
                        }
                    }

                    // Inline picker — suggested icons plus any Material
                    // Symbol by name. The name field commits on
                    // Return/blur, like the weather location field.
                    Column {
                        visible: wsRow.editing
                        width: parent.width - 28
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        spacing: 10
                        bottomPadding: 12

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.workspaceIconSuggestions

                                Rectangle {
                                    id: tile
                                    required property string modelData
                                    readonly property bool selected: wsRow.icon === modelData

                                    width: 36
                                    height: 36
                                    radius: Colors.radiusSmall
                                    color: selected ? Colors.accent
                                        : tileHover.hovered ? Colors.surface : "transparent"
                                    activeFocusOnTab: true

                                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                                    function pick() {
                                        Config.setWorkspaceIcon(wsRow.wsId, modelData);
                                        wsRow.draft = modelData;
                                    }
                                    Keys.onReturnPressed: pick()
                                    Keys.onSpacePressed: pick()

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: tile.modelData
                                        filled: tile.selected
                                        color: tile.selected ? Colors.accentText : Colors.text
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        border.width: 2
                                        border.color: Colors.accent
                                        visible: tile.activeFocus
                                    }

                                    HoverHandler { id: tileHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: tile.pick()
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width - defaultBtn.width - 8
                                height: 32
                                radius: height / 2
                                color: Colors.surface

                                TextInput {
                                    id: iconInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    color: Colors.text
                                    font.family: Config.fontFamily
                                    font.pixelSize: Config.fontSize - 1
                                    clip: true
                                    text: wsRow.draft
                                    verticalAlignment: TextInput.AlignVCenter

                                    onTextChanged: wsRow.draft = text
                                    Keys.onReturnPressed: Config.setWorkspaceIcon(wsRow.wsId, wsRow.draft.trim())
                                    onActiveFocusChanged: if (!activeFocus && wsRow.draft.trim() !== wsRow.icon) Config.setWorkspaceIcon(wsRow.wsId, wsRow.draft.trim())

                                    StyledText {
                                        visible: iconInput.text.length === 0
                                        text: "Material Symbol name, e.g. rocket_launch"
                                        opacity: 0.5
                                        font.pixelSize: Config.fontSize - 1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            Chip {
                                id: defaultBtn
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Default"
                                onClicked: {
                                    wsRow.draft = "";
                                    Config.setWorkspaceIcon(wsRow.wsId, "");
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: wsRow.index < 9
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        height: 1
                        color: Colors.overlay
                        opacity: 0.15
                    }
                }
            }
        }
    }
}
