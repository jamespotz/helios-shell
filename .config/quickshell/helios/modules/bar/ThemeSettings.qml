import QtQuick
import "../../services"
import "../../components"

// Apple Settings-style theme selector — grouped sections with clear
// hierarchy, rounded card containers, and refined preset swatches.
Item {
    id: root

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 20

        // ─── Header ──────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 4

            StyledText {
                text: "Appearance"
                font.pixelSize: Config.fontSize + 4
                font.weight: Font.Bold
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Colors.subtext
                font.pixelSize: Config.fontSize - 1
                text: Themes.currentLabel() + " · Also applies to GTK, Qt, Ghostty, btop, Neovim, Zed, Bat"
            }
        }

        // ─── Preset themes section ───────────────────────────────────────
        Column {
            width: parent.width
            spacing: 10

            StyledText {
                text: "Themes"
                font.pixelSize: Config.fontSize - 1
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                color: Colors.subtext
            }

            // Theme grid — 2 columns of rounded cards with color preview
            Grid {
                width: parent.width
                columns: 2
                spacing: 8

                Repeater {
                    model: Themes.presetOrder

                    Rectangle {
                        id: card
                        required property string modelData
                        readonly property var palette: Themes.presets[modelData]
                        readonly property bool active: Themes.mode === "preset" && Themes.presetName === modelData

                        width: (parent.width - 8) / 2
                        height: 52
                        radius: 12
                        color: card.palette.surface
                        border.width: active ? 2 : 0
                        border.color: Colors.accent

                        // Subtle inner highlight when active
                        Rectangle {
                            visible: card.active
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: "transparent"
                            border.width: 0.5
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                        }

                        // Hover overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "#ffffff"
                            opacity: cardHover.hovered && !card.active ? 0.06 : 0

                            Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                        }

                        HoverHandler { id: cardHover }

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            spacing: 10

                            // Color swatch — accent dot with background ring
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: card.palette.background
                                border.width: 1.5
                                border.color: card.palette.accent
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: card.palette.accent
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.palette.label
                                color: card.palette.text
                                font.pixelSize: Config.fontSize - 1
                                font.weight: Font.Medium
                            }
                        }

                        // Checkmark badge when active
                        Rectangle {
                            visible: card.active
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 18
                            height: 18
                            radius: 9
                            color: Colors.accent

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "check"
                                font.pixelSize: 12
                                color: Colors.accentText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Themes.applyPreset(card.modelData)
                        }
                    }
                }
            }
        }

        // ─── Dynamic theme section ───────────────────────────────────────
        Column {
            width: parent.width
            spacing: 12

            StyledText {
                text: "Wallpaper"
                font.pixelSize: Config.fontSize - 1
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                color: Colors.subtext
            }

            // Dynamic theme button — prominent when active
            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: Themes.mode === "dynamic" ? Colors.accent : Colors.surfaceHigh
                opacity: Themes.mode === "dynamic" ? 1 : 0.7

                Behavior on color { ColorAnimation { duration: Config.animFast } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        icon: "auto_awesome"
                        font.pixelSize: 18
                        color: Themes.mode === "dynamic" ? Colors.accentText : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: Themes.generating ? "Generating…" : "Dynamic (from wallpaper)"
                        color: Themes.mode === "dynamic" ? Colors.accentText : Colors.text
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Hover overlay
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "#ffffff"
                    opacity: dynamicHover.hovered ? 0.08 : 0

                    Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                }

                HoverHandler { id: dynamicHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Themes.applyDynamic()
                }
            }

            // Error message
            StyledText {
                visible: Themes.lastError.length > 0
                width: parent.width
                wrapMode: Text.WordWrap
                color: Colors.danger
                font.pixelSize: Config.fontSize - 2
                text: Themes.lastError
            }

            // ─── Palette options (only relevant when dynamic) ────────────
            Rectangle {
                width: parent.width
                height: paletteCol.implicitHeight + 24
                radius: 12
                color: Colors.surfaceHigh
                opacity: Themes.mode === "dynamic" ? 0.5 : 0.25
                visible: true

                Behavior on opacity { NumberAnimation { duration: Config.animMedium } }

                Column {
                    id: paletteCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Dark/Light toggle row
                    Row {
                        width: parent.width

                        StyledText {
                            width: parent.width - toggle.width
                            anchors.verticalCenter: parent.verticalCenter
                            font.weight: Font.Medium
                            text: "Dark Mode"
                        }

                        Toggle {
                            id: toggle
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Themes.dynamicDark
                            onToggled: v => Themes.setDynamicMode(v)
                        }
                    }

                    // Thin separator
                    Rectangle {
                        width: parent.width
                        height: 0.5
                        color: Colors.overlay
                        opacity: 0.3
                    }

                    // Palette scheme label
                    StyledText {
                        text: "Palette Scheme"
                        font.pixelSize: Config.fontSize - 1
                        font.weight: Font.Medium
                        color: Colors.subtext
                    }

                    // Scheme chips — pill-shaped selectors
                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: Themes.schemeOptions

                            Rectangle {
                                id: schemeChip
                                required property var modelData
                                readonly property bool active: Themes.paletteScheme === modelData.value

                                width: chipContent.implicitWidth + 16
                                height: 28
                                radius: 14
                                color: active ? Colors.accent : Colors.surface

                                Behavior on color { ColorAnimation { duration: Config.animFast } }

                                // Hover
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "#ffffff"
                                    opacity: chipHover.hovered && !schemeChip.active ? 0.08 : 0
                                }

                                HoverHandler { id: chipHover }

                                Row {
                                    id: chipContent
                                    anchors.centerIn: parent
                                    spacing: 5

                                    // Color swatch dots
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Repeater {
                                            model: schemeChip.modelData.swatch
                                            Rectangle {
                                                required property string modelData
                                                width: 7
                                                height: 7
                                                radius: 3.5
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: modelData
                                            }
                                        }
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: schemeChip.modelData.label
                                        font.pixelSize: Config.fontSize - 2
                                        font.weight: Font.Medium
                                        color: schemeChip.active ? Colors.accentText : Colors.text
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Themes.setPaletteScheme(schemeChip.modelData.value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
