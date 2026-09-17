import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var builtinCurves: [
        { name: "default", points: [[0.05,0.9],[0.1,1]] },
        { name: "linear", points: [[0,0],[1,1]] },
        { name: "easeInSine", points: [[0.12,0],[0.39,0]] },
        { name: "easeOutSine", points: [[0.61,1],[0.88,1]] },
        { name: "easeInOutSine", points: [[0.37,0],[0.63,1]] },
        { name: "easeInQuad", points: [[0.11,0],[0.5,0]] },
        { name: "easeOutQuad", points: [[0.5,1],[0.89,1]] },
        { name: "easeInOutQuad", points: [[0.45,0],[0.55,1]] }
    ]

    readonly property var leafNames: ["windowsIn", "windowsOut", "windowsMove", "workspaces",
        "specialWorkspace", "fade", "fadeDim", "border", "layersIn", "layersOut", "fadeLayers"]

    property var state: root.defaultState()
    property string editingCurve: ""

    implicitWidth: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    function defaultState() {
        const leaves = {};
        for (const leaf of root.leafNames)
            leaves[leaf] = { enabled: true, speed: 5, bezier: "linear", style: "" };
        return { enabled: true, curves: [], leaves: leaves };
    }

    function allCurveNames() {
        return root.builtinCurves.map(c => c.name).concat((root.state.curves || []).map(c => c.name));
    }

    function addCurve() {
        const curves = root.state.curves.slice();
        let n = 1;
        while (curves.some(c => c.name === "custom" + n)) n++;
        curves.push({ name: "custom" + n, points: [[0.25,0.1],[0.25,1]] });
        root.state = Object.assign({}, root.state, { curves: curves });
        root.editingCurve = "custom" + n;
    }

    function updateCurve(name, p1x, p1y, p2x, p2y) {
        const curves = root.state.curves.map(c => c.name === name ? Object.assign({}, c, { points: [[p1x,p1y],[p2x,p2y]] }) : c);
        root.state = Object.assign({}, root.state, { curves: curves });
    }

    function setLeaf(leaf, key, value) {
        const leaves = Object.assign({}, root.state.leaves);
        leaves[leaf] = Object.assign({}, leaves[leaf], { [key]: value });
        root.state = Object.assign({}, root.state, { leaves: leaves });
    }

    function buildLua() {
        let body = "hl.config({\n    animations = {\n        enabled = " + root.state.enabled + ",\n    },\n})\n\n";
        for (const curve of root.state.curves)
            body += "hl.curve(" + HyprlandConfig.luaValue(curve.name) + ", { type = \"bezier\", points = { { "
                + curve.points[0][0] + ", " + curve.points[0][1] + " }, { "
                + curve.points[1][0] + ", " + curve.points[1][1] + " } } })\n";
        body += "\n";
        for (const leaf of root.leafNames) {
            const l = root.state.leaves[leaf];
            body += "hl.animation({ leaf = " + HyprlandConfig.luaValue(leaf) + ", enabled = " + l.enabled
                + ", speed = " + l.speed + ", bezier = " + HyprlandConfig.luaValue(l.bezier)
                + (l.style ? ", style = " + HyprlandConfig.luaValue(l.style) : "") + " })\n";
        }
        return body;
    }

    function save() {
        // Animations has list-shaped state that doesn't fit the flat
        // path->value convention other sections use — persist the whole
        // object directly instead of per-path setSectionField calls.
        // setSectionField must run before saveSection: saveSection triggers
        // the actual disk write of the draft, so writing state after it
        // would persist a stale (pre-save) draft.
        HyprlandConfig.setSectionField("animations", "__state", root.state);
        HyprlandConfig.saveSection("animations", root.buildLua());
    }

    Component.onCompleted: {
        const saved = HyprlandConfig.sectionState("animations");
        root.state = (saved && saved.__state) ? saved.__state : root.defaultState();
    }

    Column {
        id: col
        width: parent.width
        spacing: 20

        ToggleRow {
            title: "Enable animations"
            checked: root.state.enabled
            onToggled: v => root.state = Object.assign({}, root.state, { enabled: v })
        }

        StyledText {
            text: "Saving replaces your entire animation configuration — review the curves and leaf settings below before saving for the first time."
            color: Colors.subtext
            font.pixelSize: Config.fontSize - 2
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Column {
            width: parent.width
            spacing: 8
            StyledText { text: "Curves"; font.weight: Font.DemiBold }

            Repeater {
                model: root.builtinCurves
                StyledText {
                    required property var modelData
                    text: modelData.name + " (built-in)"
                    color: Colors.subtext
                    font.pixelSize: Config.fontSize - 2
                }
            }

            Repeater {
                model: root.state.curves || []
                Column {
                    required property var modelData
                    width: col.width
                    spacing: 4
                    HoverRow {
                        width: parent.width
                        height: 32
                        onClicked: root.editingCurve = root.editingCurve === modelData.name ? "" : modelData.name
                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                        }
                    }
                    BezierCurveEditor {
                        visible: root.editingCurve === modelData.name
                        p1x: modelData.points[0][0]
                        p1y: modelData.points[0][1]
                        p2x: modelData.points[1][0]
                        p2y: modelData.points[1][1]
                        onPointsChanged: (p1x, p1y, p2x, p2y) => root.updateCurve(modelData.name, p1x, p1y, p2x, p2y)
                    }
                }
            }

            Rectangle {
                width: 100
                height: 28
                radius: height / 2
                color: Colors.surfaceHigh
                StyledText { anchors.centerIn: parent; text: "Add curve"; font.pixelSize: Config.fontSize - 2 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.addCurve() }
            }
        }

        Column {
            width: parent.width
            spacing: 10
            StyledText { text: "Animation configs"; font.weight: Font.DemiBold }

            Repeater {
                model: root.leafNames
                Column {
                    required property string modelData
                    width: col.width
                    spacing: 6

                    ToggleRow {
                        title: modelData
                        checked: root.state.leaves[modelData].enabled
                        onToggled: v => root.setLeaf(modelData, "enabled", v)
                    }
                    LabeledNumberField {
                        label: "Speed"
                        value: root.state.leaves[modelData].speed
                        minValue: 0
                        maxValue: 20
                        onValueEdited: v => root.setLeaf(modelData, "speed", v)
                    }
                    Dropdown {
                        label: "Bezier"
                        model: root.allCurveNames().map(n => ({ value: n, label: n }))
                        currentValue: root.state.leaves[modelData].bezier
                        onActivated: v => root.setLeaf(modelData, "bezier", v)
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
}
