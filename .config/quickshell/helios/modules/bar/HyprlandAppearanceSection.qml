import QtQuick
import "../../services"
import "../../components"

// Appearance. decoration/cursor/xwayland/render scalar Hyprland options,
// all rendered through the same field-spec-driven form as
// HyprlandGeneralSection.qml (Task 5). opengl:* is intentionally omitted,
// verified to have zero live-settable options on Hyprland 0.56.2.
Item {
    id: root

    // These four Lua top-level keys each get their own helios/<key>.lua.
    // luaConfigBlock is called once per top key since hl.config() takes one
    // top-level table per call in the existing hand-written modules.
    readonly property var luaTopKeys: ["decoration", "cursor", "xwayland", "render"]

    readonly property var fields: [
        { path: "decoration:rounding", label: "Rounding", type: "int", min: 0, max: 30 },
        { path: "decoration:rounding_power", label: "Rounding power", type: "float", min: 1.0, max: 4.0 },
        { path: "decoration:active_opacity", label: "Active opacity", type: "float", min: 0.0, max: 1.0 },
        { path: "decoration:inactive_opacity", label: "Inactive opacity", type: "float", min: 0.0, max: 1.0 },
        { path: "decoration:dim_inactive", label: "Dim inactive windows", type: "bool" },
        { path: "decoration:dim_strength", label: "Dim strength", type: "float", min: 0.0, max: 1.0 },
        { path: "decoration:shadow:enabled", label: "Shadow", type: "bool" },
        { path: "decoration:shadow:range", label: "Shadow range", type: "int", min: 0, max: 60 },
        { path: "decoration:shadow:render_power", label: "Shadow render power", type: "int", min: 1, max: 4 },
        { path: "decoration:shadow:sharp", label: "Sharp shadow", type: "bool" },
        { path: "decoration:blur:enabled", label: "Blur", type: "bool" },
        { path: "decoration:blur:size", label: "Blur size", type: "int", min: 1, max: 20 },
        { path: "decoration:blur:passes", label: "Blur passes", type: "int", min: 1, max: 10 },
        { path: "decoration:blur:brightness", label: "Blur brightness", type: "float", min: 0.0, max: 2.0 },
        { path: "decoration:blur:contrast", label: "Blur contrast", type: "float", min: 0.0, max: 2.0 },
        { path: "decoration:blur:vibrancy", label: "Blur vibrancy", type: "float", min: 0.0, max: 1.0 },
        { path: "decoration:blur:vibrancy_darkness", label: "Blur vibrancy darkness", type: "float", min: 0.0, max: 1.0 },
        { path: "decoration:blur:noise", label: "Blur noise", type: "float", min: 0.0, max: 1.0 },
        { path: "decoration:blur:special", label: "Blur special workspaces", type: "bool" },
        { path: "decoration:blur:xray", label: "Blur xray", type: "bool" },
        { path: "decoration:blur:popups", label: "Blur popups", type: "bool" },
        { path: "decoration:blur:input_methods", label: "Blur input methods", type: "bool" },
        { path: "cursor:no_hardware_cursors", label: "Hardware cursors", type: "enum",
          options: [{value:0,label:"Auto"},{value:1,label:"Off"},{value:2,label:"On"}] },
        { path: "cursor:inactive_timeout", label: "Cursor inactive timeout", type: "float", min: 0, max: 30 },
        { path: "cursor:zoom_factor", label: "Cursor zoom factor", type: "float", min: 0.5, max: 5.0 },
        { path: "cursor:hide_on_key_press", label: "Hide cursor on key press", type: "bool" },
        { path: "xwayland:force_zero_scaling", label: "XWayland force zero scaling", type: "bool" },
        { path: "xwayland:use_nearest_neighbor", label: "XWayland nearest-neighbor scaling", type: "bool" },
        { path: "render:direct_scanout", label: "Direct scanout", type: "enum",
          options: [{value:0,label:"Off"},{value:1,label:"On"},{value:2,label:"Only fullscreen"}] },
        { path: "render:expand_undersized_textures", label: "Expand undersized textures", type: "bool" },
        { path: "render:cm_enabled", label: "Color management", type: "bool" }
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
        // Persist the whole flat draft under section "appearance" (one
        // saved section covers all four Lua files it generates).
        for (const path of Object.keys(root.draft))
            HyprlandConfig.setSectionField("appearance", path, root.draft[path]);

        for (const key of root.luaTopKeys) {
            const flatForKey = {};
            for (const path of Object.keys(root.draft))
                if (path.startsWith(key + ":")) flatForKey[path] = root.draft[path];
            HyprlandConfig.saveSection(key, HyprlandConfig.luaConfigBlock(key, flatForKey));
        }
    }

    Component.onCompleted: {
        if (HyprlandConfig.hasSaved("appearance")) {
            root.draft = HyprlandConfig.sectionState("appearance");
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
}
