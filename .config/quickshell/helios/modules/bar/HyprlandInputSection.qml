import QtQuick
import "../../services"
import "../../components"

// Input. input/gestures scalar Hyprland options, rendered through the same
// field-spec-driven form as HyprlandGeneralSection.qml (Task 5) and
// HyprlandAppearanceSection.qml (Task 6).
Item {
    id: root

    // These two Lua top-level keys each get their own helios/<key>.lua.
    // luaConfigBlock is called once per top key since hl.config() takes one
    // top-level table per call in the existing hand-written modules.
    readonly property var luaTopKeys: ["input", "gestures"]

    readonly property var fields: [
        { path: "input:kb_layout", label: "Keyboard layout", type: "string" },
        { path: "input:numlock_by_default", label: "Numlock by default", type: "bool" },
        { path: "input:repeat_delay", label: "Repeat delay", type: "int", min: 100, max: 1000 },
        { path: "input:repeat_rate", label: "Repeat rate", type: "int", min: 10, max: 100 },
        { path: "input:follow_mouse", label: "Follow mouse", type: "enum",
          options: [{value:0,label:"None"},{value:1,label:"Always"},{value:2,label:"Only fullscreen"},{value:3,label:"Loose"}] },
        { path: "input:mouse_refocus", label: "Mouse refocus", type: "bool" },
        { path: "input:natural_scroll", label: "Natural scroll", type: "bool" },
        { path: "input:accel_profile", label: "Accel profile", type: "enum",
          options: [{value:"",label:"Default"},{value:"adaptive",label:"Adaptive"},{value:"flat",label:"Flat"}] },
        { path: "input:sensitivity", label: "Sensitivity", type: "float", min: -1.0, max: 1.0 },
        { path: "input:touchpad:natural_scroll", label: "Touchpad natural scroll", type: "bool" },
        { path: "input:touchpad:scroll_factor", label: "Touchpad scroll factor", type: "float", min: 0.1, max: 3.0 },
        { path: "gestures:workspace_swipe_touch", label: "Workspace swipe (touch)", type: "bool" },
        { path: "gestures:workspace_swipe_invert", label: "Workspace swipe invert", type: "bool" },
        { path: "gestures:workspace_swipe_distance", label: "Workspace swipe distance", type: "int", min: 100, max: 1000 },
        { path: "gestures:workspace_swipe_min_speed_to_force", label: "Swipe min speed to force", type: "int", min: 0, max: 100 },
        { path: "gestures:workspace_swipe_cancel_ratio", label: "Swipe cancel ratio", type: "float", min: 0.0, max: 1.0 },
        { path: "gestures:workspace_swipe_create_new", label: "Swipe creates new workspace", type: "bool" },
        { path: "gestures:workspace_swipe_direction_lock", label: "Swipe direction lock", type: "bool" },
        { path: "gestures:workspace_swipe_direction_lock_threshold", label: "Swipe direction lock threshold", type: "int", min: 0, max: 50 },
        { path: "gestures:workspace_swipe_forever", label: "Swipe forever", type: "bool" }
    ]

    property var draft: ({})
    property bool loading: true

    implicitWidth: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    function fieldValue(path) {
        return root.draft[path];
    }

    function setField(path, value) {
        root.draft[path] = value;
        root.draftChanged();
    }

    function save() {
        // Persist the whole flat draft under section "input" (one saved
        // section covers both Lua files it generates).
        for (const path of Object.keys(root.draft))
            HyprlandConfig.setSectionField("input", path, root.draft[path]);

        for (const key of root.luaTopKeys) {
            const flatForKey = {};
            for (const path of Object.keys(root.draft))
                if (path.startsWith(key + ":")) flatForKey[path] = root.draft[path];
            HyprlandConfig.saveSection(key, HyprlandConfig.luaConfigBlock(key, flatForKey));
        }
    }

    Component.onCompleted: {
        if (HyprlandConfig.hasSaved("input")) {
            root.draft = HyprlandConfig.sectionState("input");
            root.loading = false;
        } else {
            HyprlandConfig.readLiveOptions(root.fields.map(f => f.path), result => {
                root.draft = result;
                root.loading = false;
            });
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        StyledText {
            visible: root.loading
            text: "Loading current config…"
            color: Colors.subtext
        }

        Column {
            visible: !root.loading
            width: parent.width
            spacing: 10

            Repeater {
                model: root.fields

                Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: modelData.type === "bool" ? boolField
                        : modelData.type === "enum" ? enumField
                        : modelData.type === "float" ? decimalField
                        : modelData.type === "string" ? stringField
                        : intField
                    onLoaded: {
                        item.fieldSpec = modelData;
                    }
                }
            }
        }

        Rectangle {
            visible: HyprlandConfig.configErrors.length > 0
            width: parent.width
            implicitHeight: errText.implicitHeight + 20
            radius: Colors.radiusSmall
            color: Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.15)
            StyledText {
                id: errText
                anchors.centerIn: parent
                width: parent.width - 24
                wrapMode: Text.WordWrap
                text: HyprlandConfig.configErrors.join("\n")
                color: Colors.danger
            }
        }

        Row {
            spacing: 10
            Rectangle {
                width: 80
                height: 32
                radius: height / 2
                color: Colors.accent
                StyledText { anchors.centerIn: parent; text: "Save"; color: Colors.accentText; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.save() }
            }
        }
    }

    Component {
        id: boolField
        ToggleRow {
            property var fieldSpec: null
            title: fieldSpec ? fieldSpec.label : ""
            checked: fieldSpec ? !!root.fieldValue(fieldSpec.path) : false
            onToggled: v => root.setField(fieldSpec.path, v)
        }
    }

    Component {
        id: enumField
        Dropdown {
            property var fieldSpec: null
            label: fieldSpec ? fieldSpec.label : ""
            model: fieldSpec ? fieldSpec.options : []
            currentValue: fieldSpec ? root.fieldValue(fieldSpec.path) : null
            onActivated: v => root.setField(fieldSpec.path, v)
        }
    }

    Component {
        id: intField
        LabeledNumberField {
            property var fieldSpec: null
            label: fieldSpec ? fieldSpec.label : ""
            value: fieldSpec ? (root.fieldValue(fieldSpec.path) || 0) : 0
            minValue: fieldSpec ? fieldSpec.min : 0
            maxValue: fieldSpec ? fieldSpec.max : 999
            onValueEdited: v => root.setField(fieldSpec.path, v)
        }
    }

    Component {
        id: decimalField
        LabeledDecimalField {
            property var fieldSpec: null
            label: fieldSpec ? fieldSpec.label : ""
            value: fieldSpec ? (root.fieldValue(fieldSpec.path) || 0) : 0
            minValue: fieldSpec ? fieldSpec.min : 0
            maxValue: fieldSpec ? fieldSpec.max : 1
            decimals: 2
            onValueEdited: v => root.setField(fieldSpec.path, v)
        }
    }

    Component {
        id: stringField
        Row {
            property var fieldSpec: null
            spacing: 8
            StyledText { anchors.verticalCenter: parent.verticalCenter; width: 90; text: fieldSpec ? fieldSpec.label : ""; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
            Rectangle {
                width: 120
                height: 32
                radius: height / 2
                color: Colors.surface
                anchors.verticalCenter: parent.verticalCenter
                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Colors.text
                    font.family: Config.fontFamily
                    font.pixelSize: Config.fontSize
                    clip: true
                    text: fieldSpec ? (root.fieldValue(fieldSpec.path) || "") : ""
                    onEditingFinished: root.setField(fieldSpec.path, text)
                }
            }
        }
    }
}
