import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Settings > Dock > Pinned apps — reorder or remove pins and separators,
// and add apps from a searchable picker.
Column {
    id: root

    property bool picking: false
    // Drag reorder, same as the Dock: the dragged row follows the pointer,
    // the others make room at dropIndex, and pins change on release.
    readonly property int rowHeight: 44
    property int dragIndex: -1
    property real dragDelta: 0
    readonly property int dropIndex: root.dragIndex < 0 ? -1
        : Math.max(0, Math.min(Math.round(root.dragIndex + root.dragDelta / root.rowHeight), Dock.pins.length - 1))
    property string query: ""
    readonly property var candidates: {
        const needle = root.query.trim().toLowerCase();
        return Launcher.applications
            .filter(entry => !Dock.pins.includes(Dock.keyOf(entry)))
            .filter(entry => !needle || String(entry.name).toLowerCase().includes(needle)
                || String(entry.genericName || "").toLowerCase().includes(needle))
            .sort((a, b) => a.name.localeCompare(b.name))
            .slice(0, 8);
    }

    spacing: 8

    component AppIcon: Item {
        property string icon: ""
        width: 24
        height: 24

        MaterialIcon {
            anchors.centerIn: parent
            visible: image.source.toString() === ""
            icon: "deployed_code"
            font.pixelSize: 18
            color: Colors.subtext
        }
        Image {
            id: image
            anchors.fill: parent
            source: Quickshell.iconPath(parent.icon, true)
            sourceSize: Qt.size(48, 48)
            mipmap: true
            asynchronous: true
        }
    }

    component Hairline: Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.bottom: parent.bottom
        height: 1
        color: Colors.overlay
        opacity: 0.15
    }

    Rectangle {
        width: parent.width
        height: pinColumn.implicitHeight
        radius: Colors.radiusLarge
        color: Colors.surfaceHigh

        Column {
            id: pinColumn
            width: parent.width

            Repeater {
                model: Dock.pins

                Item {
                    id: pinRow
                    required property string modelData
                    required property int index
                    readonly property bool separator: Dock.isSeparator(pinRow.modelData)
                    readonly property bool dragged: root.dragIndex === pinRow.index
                    property real pressY: 0
                    readonly property var entry: pinRow.separator ? null : Dock.entryFor(pinRow.modelData)

                    width: pinColumn.width
                    height: root.rowHeight
                    z: pinRow.dragged ? 1 : 0

                    transform: Translate {
                        y: pinRow.dragged ? root.dragDelta
                            : root.dragIndex < pinRow.index && pinRow.index <= root.dropIndex ? -root.rowHeight
                            : root.dropIndex <= pinRow.index && pinRow.index < root.dragIndex ? root.rowHeight : 0
                        Behavior on y {
                            enabled: !pinRow.dragged && !Config.reducedMotion
                            NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: pinRow.dragged
                        radius: Colors.radiusLarge
                        color: Colors.surfaceHigh
                        border.width: 1
                        border.color: Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.3)
                    }

                    // Below the buttons, so they keep their clicks.
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        // The Settings page scrolls; keep the drag.
                        preventStealing: true
                        cursorShape: pinRow.dragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        // In pinColumn coordinates: the row itself moves while dragged.
                        function columnY(mouse) { return rowMouse.mapToItem(pinColumn, mouse.x, mouse.y).y; }
                        onPressed: mouse => { pinRow.pressY = rowMouse.columnY(mouse); }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            const delta = rowMouse.columnY(mouse) - pinRow.pressY;
                            if (root.dragIndex < 0 && Math.abs(delta) > 4) root.dragIndex = pinRow.index;
                            if (pinRow.dragged) root.dragDelta = delta;
                        }
                        onReleased: {
                            if (!pinRow.dragged) return;
                            const target = root.dropIndex;
                            root.dragIndex = -1;
                            root.dragDelta = 0;
                            if (target !== pinRow.index) Dock.placeAt(pinRow.modelData, target);
                        }
                        onCanceled: if (pinRow.dragged) { root.dragIndex = -1; root.dragDelta = 0; }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: controls.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon {
                            icon: "drag_indicator"
                            font.pixelSize: 16
                            color: Colors.subtext
                            opacity: rowMouse.containsMouse || pinRow.dragged ? 1 : 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        AppIcon {
                            visible: !pinRow.separator
                            icon: pinRow.entry ? pinRow.entry.icon : ""
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        MaterialIcon {
                            visible: pinRow.separator
                            width: 24
                            horizontalAlignment: Text.AlignHCenter
                            icon: "more_vert"
                            font.pixelSize: 18
                            color: Colors.subtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            width: parent.width - 60
                            anchors.verticalCenter: parent.verticalCenter
                            text: pinRow.separator ? "Separator" : pinRow.entry ? pinRow.entry.name : pinRow.modelData + " (not installed)"
                            color: pinRow.entry ? Colors.text : Colors.subtext
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        id: controls
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        IconButton {
                            icon: "arrow_upward"
                            label: "Move up"
                            enabled: pinRow.index > 0
                            onClicked: Dock.movePin(pinRow.modelData, -1)
                        }
                        IconButton {
                            icon: "arrow_downward"
                            label: "Move down"
                            enabled: pinRow.index < Dock.pins.length - 1
                            onClicked: Dock.movePin(pinRow.modelData, 1)
                        }
                        IconButton {
                            icon: "close"
                            label: pinRow.separator ? "Remove separator" : "Remove from Dock"
                            onClicked: Dock.unpin(pinRow.modelData)
                        }
                    }

                    Hairline { visible: !pinRow.dragged }
                }
            }

            // Add rows — the first toggles the picker below.
            Item {
                width: pinColumn.width
                height: 44

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    MaterialIcon { icon: root.picking ? "expand_less" : "add"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: Dock.pins.length === 0 ? "Pin an app…" : "Add app…"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.picking = !root.picking;
                        search.text = "";
                        if (root.picking) search.focusInput();
                    }
                }

                Hairline {}
            }

            Item {
                width: pinColumn.width
                height: 44

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    MaterialIcon { icon: "add"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Add separator"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Dock.addSeparator()
                }
            }
        }
    }

    // Picker — search plus up to eight unpinned apps.
    Column {
        visible: root.picking
        width: parent.width
        spacing: 8

        SearchField {
            id: search
            width: parent.width
            placeholder: "Search apps to pin…"
            onTextChanged: root.query = text
            onEscapePressed: root.picking = false
            onAccepted: if (root.candidates.length > 0) Dock.pin(Dock.keyOf(root.candidates[0]))
        }

        Rectangle {
            width: parent.width
            height: candidateColumn.implicitHeight
            radius: Colors.radiusLarge
            color: Colors.surfaceHigh

            Column {
                id: candidateColumn
                width: parent.width

                Repeater {
                    model: root.candidates

                    Rectangle {
                        id: candidateRow
                        required property var modelData
                        required property int index

                        width: candidateColumn.width
                        height: 40
                        radius: Colors.radiusLarge
                        color: candidateMouse.containsMouse ? Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.2) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            AppIcon { icon: candidateRow.modelData.icon; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: candidateRow.modelData.name; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MaterialIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "add_circle"
                            font.pixelSize: 18
                            color: Colors.accent
                        }

                        MouseArea {
                            id: candidateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Dock.pin(Dock.keyOf(candidateRow.modelData))
                        }

                        Hairline { visible: candidateRow.index < root.candidates.length - 1 }
                    }
                }

                StyledText {
                    visible: root.candidates.length === 0
                    width: parent.width
                    height: 40
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "No matching apps"
                    color: Colors.subtext
                }
            }
        }
    }
}
