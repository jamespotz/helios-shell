import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Default browser, file manager, viewers, etc. — thin UI over xdg-mime, which
// is what actually owns these associations (see DefaultApps.qml) — plus the
// terminal, which has no mime type and lives in Config.terminal. Same
// collapsed-row-expands-to-picker pattern as ThemeDestination's theme grid.
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

    // Apps that can open the category's files, plus the current default even
    // if it isn't registered; every app while the handler list is unknown.
    function appsFor(category) {
        if (category.appCategory) return root.apps.filter(a => a.categories.includes(category.appCategory));
        const ids = DefaultApps.handlers[category.id] || [];
        if (!ids.length) return root.apps;
        const current = DefaultApps.current[category.id];
        return root.apps.filter(a => ids.includes(a.id + ".desktop") || a.id + ".desktop" === current);
    }

    function currentFor(category) {
        if (category.id !== "terminal") return DefaultApps.current[category.id];
        const match = root.apps.find(a => a.command[0] === Config.terminal);
        return match ? match.id + ".desktop" : Config.terminal;
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
                text: "Sets the system-wide xdg-mime association, so other apps that ask the desktop for a default pick it up too. The terminal is used by Helios and its shortcuts."
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
                                text: root.labelFor(root.currentFor(categoryDelegate.modelData))
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
                        model: categoryDelegate.open ? root.appsFor(categoryDelegate.modelData) : []

                        HoverRow {
                            id: appRow
                            required property var modelData
                            width: parent.width
                            height: 40
                            highlighted: root.currentFor(categoryDelegate.modelData) === appRow.modelData.id + ".desktop"
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
