import QtQuick
import Quickshell
import "../../services"
import "../../components"

// One level of a tray item's DBusMenu, rendered as our own styled QML.
// Recursive: rows with hasChildren open another TrayMenuLevel as a submenu
// flyout anchored to the right of the triggering row.
Item {
    id: level

    // QsMenuHandle for this level — the root DBusMenuItem for the top level,
    // or a child entry (itself a handle) for nested submenus. null = hidden.
    property var menuHandle: null

    // Emitted when a leaf entry is clicked at any depth — the top-level
    // TrayMenu connects this to Bridge.closeTrayMenu() so the whole chain
    // closes on activation.
    signal leafTriggered()

    visible: menuHandle !== null
    width: 220
    height: visible ? menuColumn.implicitHeight + 8 : 0

    // Currently open submenu state for this level
    property var submenuHandle: null
    property Item submenuAnchorItem: null

    onMenuHandleChanged: {
        submenuHandle = null;
        submenuAnchorItem = null;
    }

    QsMenuOpener {
        id: opener
        menu: level.menuHandle
    }

    PanelBackground {
        anchors.fill: parent
        visible: level.visible
    }

    Column {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        spacing: 2

        Repeater {
            model: opener.children

            delegate: Item {
                id: delegateRoot
                required property var modelData

                width: menuColumn.width
                height: modelData.isSeparator ? separatorRect.height : rowRect.height
                visible: true

                // Separator
                Rectangle {
                    id: separatorRect
                    visible: delegateRoot.modelData.isSeparator
                    width: parent.width
                    height: visible ? 1 : 0
                    color: Colors.outline
                    opacity: 0.4
                }

                // Menu row
                Rectangle {
                    id: rowRect
                    visible: !delegateRoot.modelData.isSeparator
                    width: parent.width
                    height: visible ? 32 : 0
                    radius: 8
                    color: rowHover.hovered && delegateRoot.modelData.enabled
                        ? Colors.surfaceHigh : "transparent"
                    opacity: delegateRoot.modelData.enabled ? 1 : 0.4

                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    HoverHandler {
                        id: rowHover
                        enabled: delegateRoot.modelData.enabled
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        // Check/radio indicator
                        MaterialIcon {
                            id: checkIcon
                            width: visible ? 16 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                            visible: delegateRoot.modelData.buttonType !== QsMenuButtonType.None
                            color: Colors.text
                            icon: {
                                if (!checkIcon.visible) return "";
                                const checked = delegateRoot.modelData.checkState === Qt.Checked;
                                if (delegateRoot.modelData.buttonType === QsMenuButtonType.RadioButton)
                                    return checked ? "radio_button_checked" : "radio_button_unchecked";
                                return checked ? "check" : "";
                            }
                        }

                        // Label
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (checkIcon.visible ? 22 : 0) - (chevron.visible ? 20 : 0)
                            text: delegateRoot.modelData.text
                            elide: Text.ElideRight
                            color: Colors.text
                        }

                        // Submenu chevron
                        MaterialIcon {
                            id: chevron
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                            color: Colors.subtext
                            visible: delegateRoot.modelData.hasChildren
                            icon: "chevron_right"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: delegateRoot.modelData.enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (delegateRoot.modelData.hasChildren) {
                                level.submenuAnchorItem = rowRect;
                                level.submenuHandle = delegateRoot.modelData;
                            } else {
                                delegateRoot.modelData.triggered();
                                level.leafTriggered();
                            }
                        }
                    }
                }
            }
        }
    }

    // Submenu flyout — Loader with dynamic createComponent to break QML's
    // static recursive-instantiation check. The engine sees no compile-time
    // self-reference this way; the component is resolved at runtime only
    // when a submenu actually needs to open.
    Loader {
        id: submenuLoader
        active: level.submenuHandle !== null
        x: level.width - 4
        y: level.submenuAnchorItem
            ? level.submenuAnchorItem.mapToItem(level, 0, 0).y
            : 0

        onActiveChanged: {
            if (active) {
                setSource("TrayMenuLevel.qml", {
                    "menuHandle": Qt.binding(() => level.submenuHandle)
                });
            } else {
                sourceComponent = undefined;
            }
        }

        Connections {
            target: submenuLoader.item
            function onLeafTriggered() { level.leafTriggered(); }
        }
    }
}
