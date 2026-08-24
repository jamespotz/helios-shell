import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        StyledText {
            width: parent.width
            font.bold: true
            text: "Theme"
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
            text: "Current: " + Themes.currentLabel() + ". Also themes GTK, KDE/Qt, Ghostty, btop, Neovim, Zed, and Bat."
        }

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

                    width: (parent.width - parent.spacing) / 2
                    height: 44
                    radius: Colors.radiusSmall
                    color: palette.surface
                    border.width: active ? 2 : 0
                    border.color: Colors.accent

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: cardHover.hovered ? 0.2 : 0
                    }

                    HoverHandler { id: cardHover }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        spacing: 8

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: card.palette.accent
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.palette.label
                            color: card.palette.text
                            font.pixelSize: Config.fontSize - 1
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

        Rectangle {
            width: parent.width
            height: 36
            radius: Colors.radiusSmall
            color: Themes.mode === "dynamic" ? Colors.accent : Colors.surfaceHigh

            StyledText {
                anchors.centerIn: parent
                text: Themes.generating ? "Generating…" : "Dynamic (from wallpaper)"
                color: Themes.mode === "dynamic" ? Colors.accentText : Colors.text
                font.bold: true
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Colors.surfaceHigh
                opacity: dynamicHover.hovered ? 0.2 : 0
            }

            HoverHandler { id: dynamicHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Themes.applyDynamic()
            }
        }

        StyledText {
            visible: Themes.lastError.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            color: Colors.danger
            font.pixelSize: Config.fontSize - 2
            text: Themes.lastError
        }

        Row {
            width: parent.width
            opacity: Themes.mode === "dynamic" ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            StyledText {
                width: parent.width - toggle.width
                anchors.verticalCenter: parent.verticalCenter
                font.bold: true
                text: "Palette scheme"
            }

            Toggle {
                id: toggle
                anchors.verticalCenter: parent.verticalCenter
                checked: Themes.dynamicDark
                onToggled: v => Themes.setDynamicMode(v)
            }
        }

        StyledText {
            width: parent.width
            opacity: Themes.mode === "dynamic" ? 0.6 : 0.4
            font.pixelSize: Config.fontSize - 2
            text: "Dark / Light — " + (Themes.dynamicDark ? "Dark" : "Light")
        }

        Flow {
            width: parent.width
            spacing: 6
            opacity: Themes.mode === "dynamic" ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            Repeater {
                model: Themes.schemeOptions

                Rectangle {
                    id: schemeChip
                    required property var modelData
                    readonly property bool active: Themes.paletteScheme === modelData.value

                    width: schemeChipRow.implicitWidth + 20
                    height: 30
                    radius: Colors.radiusSmall
                    color: active ? Colors.accent : Colors.surfaceHigh
                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: schemeChipHover.hovered && !schemeChip.active ? 0.25 : 0
                    }

                    HoverHandler { id: schemeChipHover }

                    Row {
                        id: schemeChipRow
                        anchors.centerIn: parent
                        spacing: 6

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: schemeChip.modelData.swatch
                                Rectangle {
                                    required property string modelData
                                    width: 8
                                    height: 8
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData
                                }
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: schemeChip.modelData.label
                            font.pixelSize: Config.fontSize - 2
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
