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
                        color: Colors.overlay
                        opacity: cardHover.hovered ? 0.2 : 0
                        Behavior on opacity { NumberAnimation { duration: Config.animFast } }
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
    }
}
