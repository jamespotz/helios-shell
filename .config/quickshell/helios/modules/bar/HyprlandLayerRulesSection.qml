import QtQuick
import Quickshell.Io
import "../../services"
import "../../components"

// Layer rules — pick an active layer-shell namespace (from `hyprctl layers
// -j`) and edit its hl.layer_rule({...}) properties. List-shaped state
// persisted whole via __state, same pattern as Task 7's Animations, Task 9's
// Keybinds, and Task 10's Window rules sections. Builds hl.layer_rule(...)
// Lua directly, matching the real hand-written layer_rules.lua's argument
// shape.
Item {
    id: root

    readonly property var propDefs: [
        { key: "blur", label: "Blur", type: "bool" },
        { key: "blur_popups", label: "Blur popups", type: "bool" },
        { key: "no_anim", label: "No animation", type: "bool" },
        { key: "xray", label: "X-ray", type: "bool" },
        { key: "ignore_alpha", label: "Ignore alpha", type: "float" },
        { key: "order", label: "Order", type: "int" }
    ]

    property var state: ({ rules: [] })
    property string editingId: ""
    property bool pickerOpen: false
    property var liveNamespaces: []

    implicitWidth: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    Process {
        id: layersProc
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    const namespaces = new Set();
                    for (const monitor of Object.keys(parsed))
                        for (const level of Object.keys(parsed[monitor].levels || {}))
                            for (const surface of parsed[monitor].levels[level])
                                if (surface.namespace) namespaces.add(surface.namespace);
                    root.liveNamespaces = Array.from(namespaces);
                } catch (e) { root.liveNamespaces = []; }
            }
        }
    }

    function escapeRegex(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

    function addRule(namespace) {
        const rules = root.state.rules.slice();
        const id = "lr" + Date.now();
        rules.push({ id: id, matchNamespace: "^(" + root.escapeRegex(namespace) + ")$", props: {} });
        root.state = { rules: rules };
        root.editingId = id;
        root.pickerOpen = false;
    }

    function setRuleProp(id, key, value) {
        const rule = root.state.rules.find(r => r.id === id);
        const props = Object.assign({}, rule.props);
        if (value === null || value === "" || value === false) delete props[key];
        else props[key] = value;
        root.state = { rules: root.state.rules.map(r => r.id === id ? Object.assign({}, r, { props: props }) : r) };
    }

    function removeRule(id) {
        root.state = { rules: root.state.rules.filter(r => r.id !== id) };
        if (root.editingId === id) root.editingId = "";
    }

    function buildLua() {
        let body = "";
        for (const r of root.state.rules) {
            const parts = ["match = { namespace = " + HyprlandConfig.luaValue(r.matchNamespace) + " }"];
            for (const key of Object.keys(r.props)) parts.push(key + " = " + HyprlandConfig.luaValue(r.props[key]));
            body += "hl.layer_rule({ " + parts.join(", ") + " })\n";
        }
        return body;
    }

    function save() {
        HyprlandConfig.setSectionField("layer_rules", "__state", root.state);
        HyprlandConfig.saveSection("layer_rules", root.buildLua());
    }

    Component.onCompleted: {
        const saved = HyprlandConfig.sectionState("layer_rules");
        root.state = (saved && saved.__state) ? saved.__state : { rules: [] };
        layersProc.running = true;
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Repeater {
            model: root.state.rules
            Column {
                id: ruleItem
                required property var modelData
                width: col.width
                spacing: 6

                HoverRow {
                    width: parent.width
                    height: 36
                    onClicked: root.editingId = root.editingId === ruleItem.modelData.id ? "" : ruleItem.modelData.id
                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: ruleItem.modelData.matchNamespace
                        font.family: Config.monoFontFamily
                    }
                }

                Column {
                    visible: root.editingId === ruleItem.modelData.id
                    width: parent.width
                    spacing: 8
                    leftPadding: 10

                    Repeater {
                        model: root.propDefs
                        Loader {
                            required property var modelData
                            property var propDef: modelData
                            width: col.width - 10
                            sourceComponent: propDef.type === "bool" ? boolPropField : numPropField
                            onLoaded: { item.propDef = propDef; item.ruleId = ruleItem.modelData.id; }
                        }
                    }

                    Rectangle {
                        width: 70
                        height: 28
                        radius: height / 2
                        color: Colors.danger
                        opacity: 0.8
                        StyledText { anchors.centerIn: parent; text: "Remove"; font.pixelSize: Config.fontSize - 2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.removeRule(ruleItem.modelData.id) }
                    }
                }
            }
        }

        Rectangle {
            width: 90
            height: 28
            radius: height / 2
            color: Colors.surfaceHigh
            StyledText { anchors.centerIn: parent; text: "Add rule"; font.pixelSize: Config.fontSize - 2 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pickerOpen = true }
        }

        Column {
            visible: root.pickerOpen
            width: parent.width
            spacing: 4

            Repeater {
                model: root.liveNamespaces
                HoverRow {
                    required property string modelData
                    width: col.width
                    height: 32
                    onClicked: root.addRule(modelData)
                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        font.family: Config.monoFontFamily
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

        Rectangle {
            width: 80
            height: 32
            radius: height / 2
            color: Colors.accent
            StyledText { anchors.centerIn: parent; text: "Save"; color: Colors.accentText; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.save() }
        }
    }

    Component {
        id: boolPropField
        ToggleRow {
            property var propDef: null
            property string ruleId: ""
            title: propDef ? propDef.label : ""
            checked: !!(root.state.rules.find(r => r.id === ruleId) || {props:{}}).props[propDef ? propDef.key : ""]
            onToggled: v => root.setRuleProp(ruleId, propDef.key, v)
        }
    }

    Component {
        id: numPropField
        Row {
            property var propDef: null
            property string ruleId: ""
            spacing: 8
            StyledText { anchors.verticalCenter: parent.verticalCenter; width: 110; text: propDef ? propDef.label : ""; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
            Rectangle {
                width: 100
                height: 32
                radius: height / 2
                color: Colors.surface
                TextInput {
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Colors.text
                    font.family: Config.fontFamily
                    text: String((root.state.rules.find(r => r.id === ruleId) || {props:{}}).props[propDef ? propDef.key : ""] || "")
                    onEditingFinished: {
                        const v = propDef.type === "int" ? (parseInt(text) || null) : (parseFloat(text) || null);
                        root.setRuleProp(ruleId, propDef.key, v);
                    }
                }
            }
        }
    }
}
