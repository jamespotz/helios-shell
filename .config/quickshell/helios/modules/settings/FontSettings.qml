import QtQuick
import "../../services"
import "../../components"

// Settings > Appearance, below the theme — the shell-wide body font.
Item {
    id: root

    property bool fontPickerOpen: false
    property string fontFilterText: ""

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        SectionTitle {
            title: "Fonts"
            subtitle: "Applies everywhere in the shell. Icon and monospace fonts are unaffected."
        }

        SettingsCard {
            Column {
                width: parent.width - 28
                x: 14
                topPadding: 12
                bottomPadding: 12
                spacing: 4

                StyledText { opacity: 0.7; font.pixelSize: Config.fontSize - 2; text: "Font family" }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: root.fontPickerOpen ? Colors.radiusLarge : height / 2
                    color: Colors.surface
                    activeFocusOnTab: true

                    function toggle() {
                        root.fontPickerOpen = !root.fontPickerOpen;
                        root.fontFilterText = "";
                    }
                    Keys.onReturnPressed: toggle()
                    Keys.onSpacePressed: toggle()

                    StyledText {
                        text: Config.fontFamily
                        font.family: Config.fontFamily
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: fontPickerIcon.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }

                    MaterialIcon {
                        id: fontPickerIcon
                        icon: root.fontPickerOpen ? "expand_less" : "expand_more"
                        font.pixelSize: 16
                        opacity: 0.6
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 2
                        border.color: Colors.accent
                        visible: parent.activeFocus
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.toggle()
                    }
                }

                // Wrapped so ScrollIndicator (anchors to its target's edges)
                // is a sibling of the Flickable rather than a child inside
                // it — see NotifyCard.qml's identical reasoning.
                Item {
                    width: parent.width
                    visible: root.fontPickerOpen
                    height: visible ? 262 : 0
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Colors.radiusLarge
                        color: Colors.surface

                        Item {
                            anchors.fill: parent
                            anchors.margins: 4

                            SearchField {
                                id: fontFilterField
                                width: parent.width
                                height: 36
                                inputPixelSize: Config.fontSize - 2
                                placeholder: "Filter fonts…"
                                text: root.fontFilterText
                                onTextChanged: root.fontFilterText = text
                            }

                            ListView {
                                id: fontList
                                anchors.top: fontFilterField.bottom
                                anchors.topMargin: 4
                                anchors.bottom: parent.bottom
                                width: parent.width
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: {
                                    const filter = root.fontFilterText.toLowerCase();
                                    return filter.length === 0
                                        ? Qt.fontFamilies()
                                        : Qt.fontFamilies().filter(f => f.toLowerCase().includes(filter));
                                }

                                delegate: Rectangle {
                                    id: fontRow
                                    required property string modelData

                                    width: fontList.width
                                    height: 32
                                    radius: Colors.radiusSmall
                                    color: fontRowHover.hovered ? Colors.surfaceHigh : "transparent"

                                    StyledText {
                                        text: fontRow.modelData
                                        font.family: fontRow.modelData
                                        color: fontRow.modelData === Config.fontFamily ? Colors.accent : Colors.text
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                    }

                                    HoverHandler { id: fontRowHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Config.setOption("fontFamily", fontRow.modelData);
                                            root.fontPickerOpen = false;
                                        }
                                    }
                                }
                            }

                            ScrollIndicator { target: fontList }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width - 14
                x: 14
                height: 1
                color: Colors.overlay
                opacity: 0.15
            }

            OptionSlider { target: Config; option: "fontSize"; icon: "format_size"; label: "Size"; last: true }
        }

        Chip {
            anchors.right: parent.right
            text: "Reset"
            inactiveTint: Colors.surfaceHigh
            onClicked: Config.resetOptions(["fontFamily", "fontSize"])
        }
    }
}
