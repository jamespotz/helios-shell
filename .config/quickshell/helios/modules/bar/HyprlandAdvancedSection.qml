import QtQuick
import "../../services"
import "../../components"

// Advanced. debug/ecosystem scalar Hyprland options, rendered through the
// same field-spec-driven form as HyprlandGeneralSection.qml (Task 5) and
// HyprlandInputSection.qml (Task 8).
Item {
    id: root

    // These two Lua top-level keys each get their own helios/<key>.lua.
    // luaConfigBlock is called once per top key since hl.config() takes one
    // top-level table per call in the existing hand-written modules.
    readonly property var luaTopKeys: ["debug", "ecosystem"]

    readonly property var fields: [
        { path: "debug:overlay", label: "Debug overlay", type: "bool" },
        { path: "debug:damage_tracking", label: "Damage tracking", type: "enum",
          options: [{value:0,label:"None"},{value:1,label:"Monitor"},{value:2,label:"Full"}] },
        { path: "debug:disable_logs", label: "Disable logs", type: "bool" },
        { path: "debug:enable_stdout_logs", label: "Enable stdout logs", type: "bool" },
        { path: "debug:colored_stdout_logs", label: "Colored stdout logs", type: "bool" },
        { path: "debug:suppress_errors", label: "Suppress errors", type: "bool" },
        { path: "debug:manual_crash", label: "Manual crash", type: "int", min: 0, max: 1 },
        { path: "ecosystem:no_update_news", label: "Hide update news", type: "bool" },
        { path: "ecosystem:no_donation_nag", label: "Hide donation nag", type: "bool" }
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
        // Persist the whole flat draft under section "advanced" (one saved
        // section covers both Lua files it generates).
        for (const path of Object.keys(root.draft))
            HyprlandConfig.setSectionField("advanced", path, root.draft[path]);

        for (const key of root.luaTopKeys) {
            const flatForKey = {};
            for (const path of Object.keys(root.draft))
                if (path.startsWith(key + ":")) flatForKey[path] = root.draft[path];
            HyprlandConfig.saveSection(key, HyprlandConfig.luaConfigBlock(key, flatForKey));
        }
    }

    Component.onCompleted: {
        if (HyprlandConfig.hasSaved("advanced")) {
            root.draft = HyprlandConfig.sectionState("advanced");
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
