import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../services"
import "../../components"

// Window rules — pick a running window (Hyprland.toplevels) or an installed
// app (DesktopEntries, for rules on apps not currently open) and edit its
// hl.window_rule({...}) properties. List-shaped state persisted whole via
// __state, same pattern as Task 7's Animations and Task 9's Keybinds
// sections. Builds hl.window_rule(...) Lua directly, matching the real
// hand-written window_rules.lua's argument shape (that file aliases
// `rule = hl.window_rule`; this section calls hl.window_rule directly,
// which is equivalent).
Item {
    id: root

    readonly property var propDefs: [
        { key: "float", label: "Float", type: "bool" },
        { key: "tile", label: "Tile", type: "bool" },
        { key: "center", label: "Center", type: "bool" },
        { key: "pin", label: "Pin", type: "bool" },
        { key: "no_focus", label: "No focus", type: "bool" },
        { key: "size", label: "Size (W H)", type: "string" },
        { key: "opacity", label: "Opacity", type: "float" },
        { key: "rounding", label: "Rounding", type: "int" },
        { key: "suppress_event", label: "Suppress event", type: "string" }
    ]

    property var state: ({ rules: [] })
    property string editingId: ""
    property bool pickerOpen: false
    property string pickerTab: "running"
    property string pickerQuery: ""

    implicitWidth: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    readonly property var runningWindows: Hyprland.toplevels ? Hyprland.toplevels.values : []
    readonly property var installedApps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay).slice().sort((a, b) => a.name.localeCompare(b.name))

    readonly property var filteredRunning: {
        const q = root.pickerQuery.toLowerCase();
        return root.runningWindows.filter(w => !q || (w.title || "").toLowerCase().includes(q) || (w.wayland && w.wayland.appId || "").toLowerCase().includes(q));
    }
    readonly property var filteredInstalled: {
        const q = root.pickerQuery.toLowerCase();
        return root.installedApps.filter(a => !q || a.name.toLowerCase().includes(q));
    }

    function escapeRegex(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

    // AppLaunch.qml (services/AppLaunch.qml) reads a toplevel's window class
    // via top.lastIpcObject.class, falling back to .initialClass — that is
    // the only field Quickshell's Hyprland module actually populates for
    // this; HyprlandToplevel has no `hyprlandProps`, and `wayland.appId`,
    // while real, is not what AppLaunch relies on. Reuse the same path here.
    function addRuleFromWindow(win) {
        const ipc = win.lastIpcObject;
        const cls = ipc ? (ipc.class || ipc.initialClass || "") : "";
        root.addRule(cls);
    }

    function addRuleFromApp(app) {
        root.addRule(app.startupClass || app.id);
    }

    function addRule(cls) {
        const rules = root.state.rules.slice();
        const id = "wr" + Date.now();
        rules.push({ id: id, matchClass: "^(" + root.escapeRegex(cls) + ")$", matchTitle: "", matchWorkspace: "", props: {} });
        root.state = { rules: rules };
        root.editingId = id;
        root.pickerOpen = false;
        root.pickerQuery = "";
    }

    function updateRule(id, patch) {
        root.state = { rules: root.state.rules.map(r => r.id === id ? Object.assign({}, r, patch) : r) };
    }

    function setRuleProp(id, key, value) {
        const rule = root.state.rules.find(r => r.id === id);
        const props = Object.assign({}, rule.props);
        if (value === null || value === "" || value === false) delete props[key];
        else props[key] = value;
        root.updateRule(id, { props: props });
    }

    function removeRule(id) {
        root.state = { rules: root.state.rules.filter(r => r.id !== id) };
        if (root.editingId === id) root.editingId = "";
    }

    function buildLua() {
        let body = "";
        for (const r of root.state.rules) {
            const match = { class: r.matchClass };
            if (r.matchTitle) match.title = r.matchTitle;
            if (r.matchWorkspace) match.workspace = r.matchWorkspace;
            const parts = ["match = " + root.matchLua(match)];
            for (const key of Object.keys(r.props)) parts.push(key + " = " + HyprlandConfig.luaValue(r.props[key]));
            body += "hl.window_rule({ " + parts.join(", ") + " })\n";
        }
        return body;
    }

    function matchLua(match) {
        const inner = Object.keys(match).map(k => k + " = " + HyprlandConfig.luaValue(match[k])).join(", ");
        return "{ " + inner + " }";
    }

    function save() {
        HyprlandConfig.saveSection("window_rules", root.buildLua());
        HyprlandConfig.setSectionField("window_rules", "__state", root.state);
    }

    Component.onCompleted: {
        const saved = HyprlandConfig.sectionState("window_rules");
        root.state = (saved && saved.__state) ? saved.__state : { rules: [] };
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
                        text: ruleItem.modelData.matchClass
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
                            required property var modelData: null
                            property var propDef: modelData
                            width: col.width - 10
                            sourceComponent: propDef.type === "bool" ? boolPropField : textPropField
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
            spacing: 10

            SegmentedControl {
                model: [{value:"running",label:"Running"},{value:"installed",label:"Installed"}]
                currentValue: root.pickerTab
                onActivated: v => root.pickerTab = v
            }

            SearchField {
                width: parent.width
                placeholder: "Filter…"
                onTextChanged: root.pickerQuery = text
            }

            Repeater {
                model: root.pickerTab === "running" ? root.filteredRunning : root.filteredInstalled
                HoverRow {
                    required property var modelData
                    width: col.width
                    height: 36
                    onClicked: root.pickerTab === "running" ? root.addRuleFromWindow(modelData) : root.addRuleFromApp(modelData)
                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pickerTab === "running" ? (modelData.title || "") : modelData.name
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
        id: textPropField
        Row {
            property var propDef: null
            property string ruleId: ""
            spacing: 8
            StyledText { anchors.verticalCenter: parent.verticalCenter; width: 110; text: propDef ? propDef.label : ""; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
            Rectangle {
                width: 140
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
                        const v = propDef.type === "int" ? (parseInt(text) || null)
                            : propDef.type === "float" ? (parseFloat(text) || null)
                            : text;
                        root.setRuleProp(ruleId, propDef.key, v);
                    }
                }
            }
        }
    }
}
