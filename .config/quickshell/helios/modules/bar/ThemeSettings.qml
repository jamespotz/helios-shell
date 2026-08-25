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

            // Theme grid — 3 columns of rounded cards with color preview
            Grid {
                width: parent.width
                columns: 3
                spacing: 8

                Repeater {
                    model: Themes.presetOrder

                    Rectangle {
                        id: card
                        required property string modelData
                        readonly property var palette: Themes.presets[modelData]
                        readonly property bool active: Themes.mode === "preset" && Themes.presetName === modelData

                        width: (parent.width - 16) / 3
                        height: 64
                        radius: 12
                        color: card.palette.surface
                        border.width: active ? 2 : 0
                        border.color: Colors.accent
                        clip: true

                        // Swatch strip — background/surfaceHigh/accent, a real
                        // preview instead of a single dot, pinned to the card edge
                        Row {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 5
                            Rectangle { width: parent.width / 3; height: parent.height; color: card.palette.background }
                            Rectangle { width: parent.width / 3; height: parent.height; color: card.palette.surfaceHigh }
                            Rectangle { width: parent.width / 3; height: parent.height; color: card.palette.accent }
                        }

                        // Subtle inner highlight when active
                        Rectangle {
                            visible: card.active
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: "transparent"
                            border.width: 0.5
                            border.color: Qt.rgba(card.palette.text.r, card.palette.text.g, card.palette.text.b, 0.1)
                        }

                        // Hover overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: card.palette.text
                            opacity: cardHover.hovered && !card.active ? 0.06 : 0

                            Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                        }

                        HoverHandler { id: cardHover }

                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 3
                            spacing: 4

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: card.palette.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: card.palette.label
                                color: card.palette.text
                                font.pixelSize: Config.fontSize - 3
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                width: card.width - 10
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        // Checkmark badge when active
                        Rectangle {
                            visible: card.active
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            width: 15
                            height: 15
                            radius: 7.5
                            color: Colors.accent

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "check"
                                font.pixelSize: 10
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
            PrimaryButton {
                width: parent.width
                icon: "auto_awesome"
                text: Themes.generating ? "Generating…" : "Dynamic (from wallpaper)"
                active: Themes.mode === "dynamic"
                onClicked: Themes.applyDynamic()
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
                enabled: Themes.mode === "dynamic"

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

                            Chip {
                                id: schemeChip
                                required property var modelData
                                active: Themes.paletteScheme === modelData.value
                                text: modelData.label
                                onClicked: Themes.setPaletteScheme(modelData.value)

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
                        }
                    }
                }
            }
        }
    }
}
