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

    // Keyboard navigation
    property int focusedIndex: -1

    onMenuHandleChanged: {
        submenuHandle = null;
        submenuAnchorItem = null;
        focusedIndex = -1;
    }

    // Subtle entry animation — explains the transition
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

    QsMenuOpener {
        id: opener
        menu: level.menuHandle
    }

    PanelBackground {
        anchors.fill: parent
        visible: level.visible
    }

    // Keyboard handling
    Keys.onUpPressed: {
        if (!opener.children || opener.children.count === 0) return;
        // Skip separators going up
        let idx = level.focusedIndex - 1;
        while (idx >= 0 && opener.children.get(idx).isSeparator) idx--;
        if (idx >= 0) level.focusedIndex = idx;
    }
    Keys.onDownPressed: {
        if (!opener.children || opener.children.count === 0) return;
        let idx = level.focusedIndex + 1;
        while (idx < opener.children.count && opener.children.get(idx).isSeparator) idx++;
        if (idx < opener.children.count) level.focusedIndex = idx;
    }
    Keys.onReturnPressed: activateFocused()
    Keys.onEnterPressed: activateFocused()
    Keys.onRightPressed: {
        // Open submenu if focused row has children
        if (focusedIndex >= 0 && focusedIndex < opener.children.count) {
            const entry = opener.children.get(focusedIndex);
            if (entry.hasChildren) {
                level.submenuHandle = entry;
            }
        }
    }
    Keys.onLeftPressed: {
        // Close this submenu level (parent will handle)
        level.menuHandle = null;
    }

    function activateFocused() {
        if (focusedIndex < 0 || focusedIndex >= opener.children.count) return;
        const entry = opener.children.get(focusedIndex);
        if (!entry.enabled || entry.isSeparator) return;
        if (entry.hasChildren) {
            level.submenuHandle = entry;
        } else {
            entry.triggered();
            level.leafTriggered();
        }
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
                required property int index

                width: menuColumn.width
                height: modelData.isSeparator ? separatorRect.height : rowRect.height

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
                    radius: Colors.radiusSmall
                    opacity: delegateRoot.modelData.enabled ? 1 : 0.4

                    readonly property bool isFocused: level.focusedIndex === delegateRoot.index
                    readonly property bool isHovered: rowHover.hovered && delegateRoot.modelData.enabled
                    readonly property bool isPressed: rowMouse.pressed && delegateRoot.modelData.enabled

                    color: isPressed ? Colors.overlay
                        : (isHovered || isFocused) ? Colors.surfaceHigh
                        : "transparent"

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
                            font.pixelSize: Config.fontSize
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
                            font.pixelSize: Config.fontSize
                            color: Colors.subtext
                            visible: delegateRoot.modelData.hasChildren
                            icon: "chevron_right"
                        }
                    }

                    MouseArea {
                        id: rowMouse
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

    // Submenu flyout — Loader with dynamic setSource to break QML's
    // static recursive-instantiation check. The engine sees no compile-time
    // self-reference; the component is resolved at runtime only when a
    // submenu actually needs to open.
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
