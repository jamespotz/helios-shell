import QtQuick
import "../../services"
import "../../components"

// General/Misc/Group — flat scalar Hyprland options, all rendered through
// the same field-spec-driven form. Appearance/Input/Advanced (Tasks 6, 8,
// 12) copy this file's structure, changing only sectionKey/fields/luaTopKeys.
Item {
    id: root

    // These three Lua top-level keys all live in helios/general.lua —
    // luaConfigBlock is called once per top key since hl.config() takes one
    // top-level table per call in the existing hand-written modules.
    readonly property var luaTopKeys: ["general", "misc", "group"]

    readonly property var fields: [
        { path: "general:gaps_in", label: "Gaps in", type: "int", min: 0, max: 50 },
        { path: "general:gaps_out", label: "Gaps out", type: "int", min: 0, max: 50 },
        { path: "general:border_size", label: "Border size", type: "int", min: 0, max: 10 },
        { path: "general:layout", label: "Layout", type: "enum",
          options: [{value:"dwindle",label:"Dwindle"},{value:"master",label:"Master"},{value:"scrolling",label:"Scrolling"}] },
        { path: "general:resize_on_border", label: "Resize on border", type: "bool" },
        { path: "general:extend_border_grab_area", label: "Border grab area", type: "int", min: 0, max: 50 },
        { path: "general:hover_icon_on_border", label: "Hover icon on border", type: "bool" },
        { path: "general:snap:enabled", label: "Window snapping", type: "bool" },
        { path: "general:snap:window_gap", label: "Snap gap", type: "int", min: 0, max: 50 },
        { path: "misc:animate_manual_resizes", label: "Animate manual resizes", type: "bool" },
        { path: "misc:animate_mouse_windowdragging", label: "Animate mouse dragging", type: "bool" },
        { path: "misc:disable_hyprland_logo", label: "Hide Hyprland logo", type: "bool" },
        { path: "misc:vrr", label: "Variable refresh rate", type: "enum",
          options: [{value:0,label:"Off"},{value:1,label:"On"},{value:2,label:"Fullscreen only"}] },
        { path: "misc:mouse_move_enables_dpms", label: "Mouse wakes display", type: "bool" },
        { path: "misc:key_press_enables_dpms", label: "Key press wakes display", type: "bool" },
        { path: "misc:focus_on_activate", label: "Focus on activate request", type: "bool" },
        { path: "misc:middle_click_paste", label: "Middle-click paste", type: "bool" },
        { path: "misc:enable_swallow", label: "Terminal swallowing", type: "bool" },
        { path: "group:insert_after_current", label: "Insert after current window", type: "bool" },
        { path: "group:focus_removed_window", label: "Focus window removed from group", type: "bool" },
        { path: "group:drag_into_group", label: "Drag into group", type: "enum",
          options: [{value:0,label:"Disabled"},{value:1,label:"Enabled"},{value:2,label:"No modifier"}] }
    ]

    property var draft: ({})
    property bool loading: true
    property bool saving: false

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
        root.saving = true;
        // Persist the whole flat draft under section "general" (one saved
        // section covers all three Lua files it generates).
        for (const path of Object.keys(root.draft))
            HyprlandConfig.setSectionField("general", path, root.draft[path]);

        for (const key of root.luaTopKeys) {
            const flatForKey = {};
            for (const path of Object.keys(root.draft))
                if (path.startsWith(key + ":")) flatForKey[path] = root.draft[path];
            HyprlandConfig.saveSection(key, HyprlandConfig.luaConfigBlock(key, flatForKey));
        }
        root.saving = false;
    }

    Component.onCompleted: {
        if (HyprlandConfig.hasSaved("general")) {
            root.draft = HyprlandConfig.sectionState("general");
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
            color: Colors.danger
            opacity: 0.15
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
}
