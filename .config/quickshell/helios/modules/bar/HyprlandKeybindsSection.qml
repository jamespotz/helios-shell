import QtQuick
import Quickshell.Io
import "../../services"
import "../../components"

// Keybinds. Read-only live-binds list (hyprctl binds -j, same Process
// pattern as KeybindsIsland) plus Helios-managed binds: each maps to a
// dispatcher form (structured args) or a raw hl.dsp.* passthrough
// expression. List-shaped state persisted whole via __state, same pattern
// as Task 7's Animations section. Builds hl.bind(...) Lua directly instead
// of luaConfigBlock since binds don't fit the flat-path convention.
Item {
    id: root

    // rawArg: true marks dispatchers whose real Lua signature (verified
    // against ~/dotfiles/.config/hypr/modules/binds.lua) takes one bare
    // string argument, e.g. hl.dsp.exec_cmd("cmd"), rather than a table
    // like hl.dsp.window.resize({ x = .., y = .. }).
    readonly property var dispatchers: [
        { value: "exec_cmd", label: "Run command", argFields: [{key:"cmd", label:"Command", type:"string"}], rawArg: true },
        { value: "window.move", label: "Move window (direction)", argFields: [{key:"direction", label:"Direction", type:"enum", options:["up","down","left","right"]}] },
        { value: "window.resize", label: "Resize window", argFields: [{key:"x", label:"X", type:"int"}, {key:"y", label:"Y", type:"int"}] },
        { value: "window.float", label: "Toggle float", argFields: [] },
        { value: "window.fullscreen", label: "Toggle fullscreen", argFields: [] },
        { value: "window.cycle_next", label: "Cycle next window", argFields: [] },
        { value: "layout", label: "Layout command", argFields: [{key:"cmd", label:"Command string", type:"string"}], rawArg: true },
        { value: "workspace.toggle_special", label: "Toggle special workspace", argFields: [{key:"name", label:"Name", type:"string"}], rawArg: true },
        { value: "raw", label: "Raw hl.dsp.* expression", argFields: [] }
    ]

    property var liveBinds: []
    property var state: ({ binds: [] })
    property string editingId: ""

    implicitWidth: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    function dispatcherSpec(value) { return root.dispatchers.find(d => d.value === value) || root.dispatchers[0]; }

    function addBind() {
        const binds = root.state.binds.slice();
        const id = "b" + Date.now();
        binds.push({ id: id, combo: "", dispatcher: "exec_cmd", args: { cmd: "" }, raw: "", description: "", locked: false });
        root.state = { binds: binds };
        root.editingId = id;
    }

    function updateBind(id, patch) {
        const binds = root.state.binds.map(b => b.id === id ? Object.assign({}, b, patch) : b);
        root.state = { binds: binds };
    }

    function removeBind(id) {
        root.state = { binds: root.state.binds.filter(b => b.id !== id) };
        if (root.editingId === id) root.editingId = "";
    }

    function dispatcherCall(bind) {
        if (bind.dispatcher === "raw") return bind.raw;
        const spec = root.dispatcherSpec(bind.dispatcher);
        if (spec.argFields.length === 0) return "hl.dsp." + bind.dispatcher + "()";
        if (spec.rawArg) return "hl.dsp." + bind.dispatcher + "(" + HyprlandConfig.luaValue(bind.args[spec.argFields[0].key]) + ")";
        const argsLua = spec.argFields.map(f => f.key + " = " + HyprlandConfig.luaValue(bind.args[f.key])).join(", ");
        return "hl.dsp." + bind.dispatcher + "({ " + argsLua + " })";
    }

    function buildLua() {
        let body = "";
        for (const b of root.state.binds) {
            if (!b.combo || (b.dispatcher === "raw" && !b.raw)) continue;
            body += "hl.bind(" + HyprlandConfig.luaValue(b.combo) + ", " + root.dispatcherCall(b)
                + ", { description = " + HyprlandConfig.luaValue(b.description)
                + (b.locked ? ", locked = true" : "") + " })\n";
        }
        return body;
    }

    function save() {
        HyprlandConfig.setSectionField("binds", "__state", root.state);
        HyprlandConfig.saveSection("binds", root.buildLua());
    }

    Component.onCompleted: {
        const saved = HyprlandConfig.sectionState("binds");
        root.state = (saved && saved.__state) ? saved.__state : { binds: [] };
        liveBindsProc.running = true;
    }

    Process {
        id: liveBindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.liveBinds = JSON.parse(text).filter(b => b.description); }
                catch (e) { root.liveBinds = []; }
            }
        }
    }

    // Arg-field row for one dispatcher argument. Both the bind row and the
    // field spec are passed in as explicit properties from the two nested
    // Repeaters' own modelData (bindRow via the outer delegate's id, argField
    // via this Repeater's own modelData). No parent-chain walking.
    component ArgFieldRow: Row {
        id: argFieldRow
        required property var argField
        required property var bindRow

        spacing: 8
        StyledText { anchors.verticalCenter: parent.verticalCenter; width: 90; text: argFieldRow.argField.label; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
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
                Component.onCompleted: text = String((argFieldRow.bindRow.args || {})[argFieldRow.argField.key] || "")
                onEditingFinished: {
                    const key = argFieldRow.argField.key;
                    const args = Object.assign({}, argFieldRow.bindRow.args, { [key]: argFieldRow.argField.type === "int" ? parseInt(text) || 0 : text });
                    root.updateBind(argFieldRow.bindRow.id, { args: args });
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
            StyledText { text: "Live binds (read-only)"; font.weight: Font.DemiBold }
            Repeater {
                model: root.liveBinds
                StyledText {
                    required property var modelData
                    text: modelData.description
                    color: Colors.subtext
                    font.pixelSize: Config.fontSize - 2
                }
            }
        }

        Column {
            width: parent.width
            spacing: 10
            StyledText { text: "Helios-managed binds"; font.weight: Font.DemiBold }

            Repeater {
                model: root.state.binds
                Column {
                    id: bindRowItem
                    required property var modelData
                    width: col.width
                    spacing: 8

                    HoverRow {
                        width: parent.width
                        height: 36
                        onClicked: root.editingId = root.editingId === bindRowItem.modelData.id ? "" : bindRowItem.modelData.id
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            StyledText { text: bindRowItem.modelData.combo || "(unset)"; font.family: Config.monoFontFamily }
                            StyledText { text: bindRowItem.modelData.description; color: Colors.subtext }
                        }
                    }

                    Column {
                        visible: root.editingId === bindRowItem.modelData.id
                        width: parent.width
                        spacing: 8
                        leftPadding: 10

                        Row {
                            spacing: 8
                            StyledText { anchors.verticalCenter: parent.verticalCenter; width: 90; text: "Combo"; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
                            Rectangle {
                                width: 200
                                height: 32
                                radius: height / 2
                                color: Colors.surface
                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: Colors.text
                                    font.family: Config.fontFamily
                                    text: bindRowItem.modelData.combo
                                    onEditingFinished: root.updateBind(bindRowItem.modelData.id, { combo: text })
                                }
                            }
                        }

                        Dropdown {
                            label: "Action"
                            width: 300
                            model: root.dispatchers.map(d => ({ value: d.value, label: d.label }))
                            currentValue: bindRowItem.modelData.dispatcher
                            onActivated: v => root.updateBind(bindRowItem.modelData.id, { dispatcher: v, args: {} })
                        }

                        Repeater {
                            model: root.dispatcherSpec(bindRowItem.modelData.dispatcher).argFields
                            ArgFieldRow {
                                required property var modelData
                                argField: modelData
                                bindRow: bindRowItem.modelData
                            }
                        }

                        Row {
                            visible: bindRowItem.modelData.dispatcher === "raw"
                            spacing: 8
                            StyledText { anchors.verticalCenter: parent.verticalCenter; width: 90; text: "Raw expr"; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
                            Rectangle {
                                width: 300
                                height: 32
                                radius: height / 2
                                color: Colors.surface
                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: Colors.text
                                    font.family: Config.monoFontFamily
                                    text: bindRowItem.modelData.raw
                                    onEditingFinished: root.updateBind(bindRowItem.modelData.id, { raw: text })
                                }
                            }
                        }

                        Row {
                            spacing: 8
                            StyledText { anchors.verticalCenter: parent.verticalCenter; width: 90; text: "Description"; opacity: 0.7; font.pixelSize: Config.fontSize - 2 }
                            Rectangle {
                                width: 200
                                height: 32
                                radius: height / 2
                                color: Colors.surface
                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: Colors.text
                                    font.family: Config.fontFamily
                                    text: bindRowItem.modelData.description
                                    onEditingFinished: root.updateBind(bindRowItem.modelData.id, { description: text })
                                }
                            }
                        }

                        Rectangle {
                            width: 70
                            height: 28
                            radius: height / 2
                            color: Colors.danger
                            opacity: 0.8
                            StyledText { anchors.centerIn: parent; text: "Remove"; font.pixelSize: Config.fontSize - 2 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.removeBind(bindRowItem.modelData.id) }
                        }
                    }
                }
            }

            Rectangle {
                width: 100
                height: 28
                radius: height / 2
                color: Colors.surfaceHigh
                StyledText { anchors.centerIn: parent; text: "Add bind"; font.pixelSize: Config.fontSize - 2 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.addBind() }
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
}
