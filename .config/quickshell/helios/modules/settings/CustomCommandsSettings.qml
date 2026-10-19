import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Settings > Custom Commands — record a key combination and pick the app it
// opens. CustomCommands.qml owns the list and writes the Hyprland binds.
// The editor opens in place, under the row (or the Add row) that opened it.
Item {
    id: root

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    // -2 closed, -1 adding, otherwise editing CustomCommands.commands[editingIndex].
    property int editingIndex: -2
    property var draftCombo: null
    property string draftApp: ""

    readonly property var apps: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay)
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property string conflict: root.draftCombo
        ? CustomCommands.conflictFor(root.draftCombo, Keybinds.all, root.editingIndex) : ""

    readonly property bool canSave: root.draftCombo !== null && root.draftApp !== "" && root.conflict === ""

    // A desktop entry or a CustomCommands target, both with id/name/icon.
    function appEntry(id) { return CustomCommands.target(id) || root.apps.find(a => a.id === id) || null; }

    // Same row again closes it, like Default Apps.
    function toggleEditor(index) {
        if (root.editingIndex === index) {
            root.closeEditor();
            return;
        }
        const command = CustomCommands.commands[index] || null;
        root.draftCombo = command ? { mods: command.mods, key: command.key } : null;
        root.draftApp = command ? command.app : "";
        root.editingIndex = index;
    }

    function closeEditor() { root.editingIndex = -2; }

    function save() {
        if (!root.canSave) return;
        const entry = root.appEntry(root.draftApp);
        const command = {
            mods: root.draftCombo.mods,
            key: root.draftCombo.key,
            app: root.draftApp,
            name: entry ? entry.name : root.draftApp
        };
        if (root.editingIndex >= 0) CustomCommands.replace(root.editingIndex, command);
        else CustomCommands.add(command);
        root.closeEditor();
    }

    function remove() {
        CustomCommands.remove(root.editingIndex);
        root.closeEditor();
    }

    Component.onCompleted: Keybinds.refresh()

    // Targets carry a Material icon name; desktop entries an icon theme name.
    component AppIcon: Item {
        id: appIcon
        property var entry: null
        readonly property bool target: appIcon.entry !== null && CustomCommands.target(appIcon.entry.id) !== null
        width: 20
        height: 20

        Image {
            anchors.fill: parent
            visible: !appIcon.target
            source: appIcon.entry && !appIcon.target ? Quickshell.iconPath(appIcon.entry.icon, true) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: appIcon.target
            icon: appIcon.target ? appIcon.entry.icon : ""
            font.pixelSize: 18
            color: Colors.accent
        }
    }

    component KeyCaps: Row {
        id: caps
        property var combo: null
        spacing: 4

        Repeater {
            model: caps.combo ? CustomCommands.comboLabels(caps.combo) : []

            Rectangle {
                required property string modelData
                width: keyText.implicitWidth + 14
                height: 24
                radius: 6
                color: Colors.surface
                border.width: 0.5
                border.color: Colors.overlay

                StyledText {
                    id: keyText
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: Config.fontSize - 2
                    font.family: Config.monoFontFamily
                    font.weight: Font.Medium
                }
            }
        }
    }

    // ─── Editor ───────────────────────────────────────────────────────────
    Component {
        id: editorComponent

        Column {
            id: editor
            // Modifiers held right now while recording, shown before the key lands.
            property var held: []
            property bool recording: false
            // The app list starts open only when there's no app yet.
            property bool picking: root.draftApp === ""

            readonly property var filteredApps: {
                const q = appSearch.text.trim().toLowerCase();
                const all = CustomCommands.targets.concat(root.apps);
                return q ? all.filter(a => a.name.toLowerCase().includes(q)) : all;
            }

            function startRecording() {
                editor.held = [];
                editor.recording = true;
                recorder.forceActiveFocus();
            }

            width: parent ? parent.width : 0
            leftPadding: 14
            rightPadding: 14
            topPadding: 4
            bottomPadding: 14
            spacing: 10

            opacity: 0
            Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
            Component.onCompleted: {
                opacity = 1;
                if (root.draftCombo === null) editor.startRecording();
            }

            // Escape closes the editor before it can close the window.
            Keys.onEscapePressed: root.closeEditor()

            Rectangle {
                id: recorder
                width: editor.width - editor.leftPadding - editor.rightPadding
                height: 44
                radius: Colors.radiusSmall
                color: Colors.surface
                border.width: editor.recording || root.conflict ? 2 : 0
                border.color: root.conflict ? Colors.danger : Colors.accent
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: editor.recording ? "Recording key combo" : "Record key combo"

                readonly property var shown: editor.recording
                    ? (editor.held.length > 0 ? { mods: editor.held, key: "" } : null)
                    : root.draftCombo

                Behavior on border.color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

                KeyCaps {
                    visible: recorder.shown !== null
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    combo: recorder.shown
                }

                StyledText {
                    visible: recorder.shown === null
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.subtext
                    text: editor.recording ? "Press a key combination" : "Click to record"
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Config.fontSize - 2
                    color: editor.recording ? Colors.accent : Colors.subtext
                    text: editor.recording ? "Esc to stop" : (root.draftCombo ? "Record again" : "")
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editor.startRecording()
                }

                onActiveFocusChanged: if (!activeFocus) editor.recording = false

                // Swallows every key while recording so Escape, Tab, and
                // Return become part of the combo rather than closing the
                // window or moving focus. Escape alone stops recording.
                Keys.onPressed: event => {
                    if (!editor.recording) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                            editor.startRecording();
                            event.accepted = true;
                        }
                        return;
                    }
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                        editor.recording = false;
                        return;
                    }
                    editor.held = CustomCommands.heldModifiers(event.key, event.modifiers, true);
                    const combo = CustomCommands.comboFromKey(event.key, event.modifiers);
                    if (!combo) return;
                    root.draftCombo = combo;
                    editor.recording = false;
                }
                Keys.onReleased: event => {
                    if (!editor.recording) return;
                    event.accepted = true;
                    editor.held = CustomCommands.heldModifiers(event.key, event.modifiers, false);
                }
            }

            StyledText {
                visible: root.conflict !== ""
                width: recorder.width
                wrapMode: Text.WordWrap
                color: Colors.danger
                font.pixelSize: Config.fontSize - 1
                text: "Already used by “" + root.conflict + "”"
            }

            // Chosen app, collapsed; tap to change it.
            HoverRow {
                id: appChoice
                width: recorder.width
                height: 44
                label: "Choose app"
                highlighted: editor.picking
                onClicked: {
                    editor.picking = !editor.picking;
                    if (editor.picking) appSearch.focusInput();
                }

                readonly property var entry: root.appEntry(root.draftApp)

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    AppIcon {
                        visible: appChoice.entry !== null
                        anchors.verticalCenter: parent.verticalCenter
                        entry: appChoice.entry
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: appChoice.entry ? appChoice.entry.name : "Choose an app"
                        color: appChoice.entry ? Colors.text : Colors.subtext
                    }
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    icon: editor.picking ? "expand_less" : "expand_more"
                    font.pixelSize: 15
                    color: Colors.accent
                }
            }

            Column {
                visible: editor.picking
                width: recorder.width
                spacing: 8

                SearchField {
                    id: appSearch
                    width: parent.width
                    placeholder: "Search apps"
                    onEscapePressed: root.closeEditor()
                    onAccepted: if (editor.filteredApps.length > 0) {
                        root.draftApp = editor.filteredApps[0].id;
                        editor.picking = false;
                    }
                }

                Item {
                    width: parent.width
                    height: 176

                    Flickable {
                        id: appFlick
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: appList.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick

                        Column {
                            id: appList
                            width: appFlick.width
                            spacing: 2

                            Repeater {
                                model: editor.filteredApps

                                HoverRow {
                                    id: appRow
                                    required property var modelData
                                    width: appList.width
                                    height: 40
                                    label: appRow.modelData.name
                                    highlighted: root.draftApp === appRow.modelData.id
                                    onClicked: {
                                        root.draftApp = appRow.modelData.id;
                                        editor.picking = false;
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        AppIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            entry: appRow.modelData
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

                    ScrollIndicator { target: appFlick }
                }
            }

            // Remove on the left, away from Save; the commit pair on the right.
            Item {
                width: recorder.width
                height: 36

                PrimaryButton {
                    visible: root.editingIndex >= 0
                    width: 96
                    height: 36
                    icon: "delete"
                    text: "Remove"
                    onClicked: root.remove()
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    PrimaryButton {
                        width: 88
                        height: 36
                        text: "Cancel"
                        onClicked: root.closeEditor()
                    }

                    PrimaryButton {
                        width: 88
                        height: 36
                        text: "Save"
                        active: true
                        enabled: root.canSave
                        onClicked: root.save()
                    }
                }
            }
        }
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
                MaterialIcon { icon: "keyboard_command_key"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    text: "Custom Commands"
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
                text: "Open an app with a key combination. Changes apply right away."
            }
        }

        SettingsCard {
            Item {
                visible: CustomCommands.commands.length > 0
                width: parent.width
                height: 32

                StyledText {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Key combo"
                    font.pixelSize: Config.fontSize - 2
                    color: Colors.subtext
                }
                StyledText {
                    x: 200
                    anchors.verticalCenter: parent.verticalCenter
                    text: "App to run"
                    font.pixelSize: Config.fontSize - 2
                    color: Colors.subtext
                }
            }

            Repeater {
                model: CustomCommands.commands

                Column {
                    id: commandRow
                    required property var modelData
                    required property int index
                    readonly property bool open: root.editingIndex === commandRow.index
                    readonly property var entry: root.appEntry(commandRow.modelData.app)
                    width: parent.width

                    HoverRow {
                        width: parent.width
                        height: 44
                        label: "Edit " + CustomCommands.bindString(commandRow.modelData)
                        onClicked: root.toggleEditor(commandRow.index)

                        KeyCaps {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            combo: commandRow.modelData
                        }

                        Row {
                            x: 200
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            AppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                entry: commandRow.entry
                            }

                            StyledText {
                                text: commandRow.modelData.name
                                color: commandRow.entry ? Colors.text : Colors.subtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MaterialIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            icon: commandRow.open ? "expand_less" : "chevron_right"
                            font.pixelSize: 15
                            color: Colors.accent
                        }
                    }

                    Loader {
                        width: parent.width
                        active: commandRow.open
                        visible: active
                        sourceComponent: editorComponent
                    }
                }
            }

            HoverRow {
                width: parent.width
                height: 44
                label: "Add Command"
                onClicked: root.toggleEditor(-1)

                Row {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    MaterialIcon {
                        icon: "add"
                        font.pixelSize: 16
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: "Add Command"
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Loader {
                width: parent.width
                active: root.editingIndex === -1
                visible: active
                sourceComponent: editorComponent
            }
        }
    }
}
