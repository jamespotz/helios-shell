import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Default browser/file manager/text editor — thin UI over xdg-mime, which
// is what actually owns these associations (see DefaultApps.qml). Same
// collapsed-row-expands-to-picker pattern as ThemeSettings' theme grid.
Item {
    id: root

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    property string openCategory: ""

    readonly property var apps: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay)
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))

    function labelFor(desktopId) {
        if (!desktopId) return "Not set";
        const bare = desktopId.replace(/\.desktop$/, "");
        const match = root.apps.find(a => a.id === bare);
        return match ? match.name : bare;
    }

    Column {
        id: col
        width: parent.width
        spacing: 20

        Column {
            width: parent.width
            spacing: 4

            Row {
                spacing: 8
                MaterialIcon { icon: "apps"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    text: "Default Apps"
                    font.pixelSize: Config.fontSize + 4
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Colors.subtext
                font.pixelSize: Config.fontSize - 1
                text: "Sets the system-wide xdg-mime association, so other apps that ask the desktop for a default pick it up too."
            }
        }

        Repeater {
            model: DefaultApps.categories

            Column {
                id: categoryDelegate
                required property var modelData
                width: parent.width
                spacing: 8

                readonly property bool open: root.openCategory === categoryDelegate.modelData.id

                HoverRow {
                    width: parent.width
                    height: 44
                    highlighted: categoryDelegate.open
                    onClicked: root.openCategory = categoryDelegate.open ? "" : categoryDelegate.modelData.id

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon {
                            icon: categoryDelegate.modelData.icon
                            font.pixelSize: 18
                            color: Colors.text
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText { text: categoryDelegate.modelData.label; font.weight: Font.Medium }
                            StyledText {
                                text: root.labelFor(DefaultApps.current[categoryDelegate.modelData.id])
                                font.pixelSize: Config.fontSize - 3
                                color: Colors.subtext
                            }
                        }
                    }

                    MaterialIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        icon: categoryDelegate.open ? "expand_less" : "chevron_right"
                        font.pixelSize: 15
                        color: Colors.accent
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2
                    visible: categoryDelegate.open

                    Repeater {
                        model: root.apps

                        HoverRow {
                            id: appRow
                            required property var modelData
                            width: parent.width
                            height: 40
                            highlighted: DefaultApps.current[categoryDelegate.modelData.id] === appRow.modelData.id + ".desktop"
                            onClicked: DefaultApps.setDefault(categoryDelegate.modelData.id, appRow.modelData.id + ".desktop")

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Image {
                                    width: 20
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: Quickshell.iconPath(appRow.modelData.icon, true)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                StyledText {
                                    text: appRow.modelData.name
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MaterialIcon {
                                visible: appRow.highlighted
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "check"
                                font.pixelSize: 15
                                color: Colors.accent
                            }
                        }
                    }
                }
            }
        }
    }
}
