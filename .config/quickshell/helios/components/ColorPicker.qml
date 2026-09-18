import QtQuick
import Quickshell.Io
import "../services"

// Hue/saturation color picker: SV square, hue strip, hex entry,
// eyedropper (samples any on-screen pixel via grim+slurp), and a row of
// caller-supplied recent swatches. Stateless about persistence — callers
// listen to colorChosen and decide what to keep.
Item {
    id: root

    property color value: "#e5484d"
    property var recentColors: []

    signal colorChosen(color color)

    implicitWidth: 220
    implicitHeight: col.implicitHeight

    // --- HSV state, kept in sync with `value` -----------------------------
    property real hue: 0
    property real sat: 1
    property real val: 1
    property bool _internalUpdate: false

    function _syncFromValue() {
        if (root._internalUpdate)
            return;
        const c = root.value;
        const max = Math.max(c.r, c.g, c.b);
        const min = Math.min(c.r, c.g, c.b);
        const d = max - min;
        let h = 0;
        if (d > 0) {
            if (max === c.r)
                h = ((c.g - c.b) / d) % 6;
            else if (max === c.g)
                h = (c.b - c.r) / d + 2;
            else
                h = (c.r - c.g) / d + 4;
            h *= 60;
            if (h < 0)
                h += 360;
        }
        root.hue = h;
        root.sat = max > 0 ? d / max : 0;
        root.val = max;
    }

    function _commit() {
        const c = Qt.hsva(root.hue / 360, root.sat, root.val, 1);
        root._internalUpdate = true;
        root.value = c;
        root._internalUpdate = false;
        root.colorChosen(c);
    }

    onValueChanged: root._syncFromValue()
    Component.onCompleted: root._syncFromValue()

    Column {
        id: col
        width: root.width
        spacing: 12

        // --- SV square ------------------------------------------------
        Rectangle {
            id: svSquare
            width: parent.width
            height: width
            radius: Colors.radiusSmall
            color: Qt.hsva(root.hue / 360, 1, 1, 1)

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: "#ffffff"
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#000000"
                    }
                }
            }

            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: "transparent"
                border.width: 2
                border.color: "#ffffff"
                x: root.sat * svSquare.width - width / 2
                y: (1 - root.val) * svSquare.height - height / 2
            }

            MouseArea {
                anchors.fill: parent
                function pick(mx, my) {
                    root.sat = Math.max(0, Math.min(1, mx / width));
                    root.val = 1 - Math.max(0, Math.min(1, my / height));
                    root._commit();
                }
                onPressed: mouse => pick(mouse.x, mouse.y)
                onPositionChanged: mouse => {
                    if (pressed)
                        pick(mouse.x, mouse.y);
                }
            }
        }

        // --- Hue strip --------------------------------------------------
        Rectangle {
            id: hueStrip
            width: parent.width
            height: 14
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.000
                    color: "#ff0000"
                }
                GradientStop {
                    position: 0.167
                    color: "#ffff00"
                }
                GradientStop {
                    position: 0.333
                    color: "#00ff00"
                }
                GradientStop {
                    position: 0.500
                    color: "#00ffff"
                }
                GradientStop {
                    position: 0.667
                    color: "#0000ff"
                }
                GradientStop {
                    position: 0.833
                    color: "#ff00ff"
                }
                GradientStop {
                    position: 1.000
                    color: "#ff0000"
                }
            }

            Rectangle {
                width: 6
                height: hueStrip.height + 6
                radius: 3
                color: "#ffffff"
                border.width: 1
                border.color: Colors.background
                anchors.verticalCenter: parent.verticalCenter
                x: (root.hue / 360) * hueStrip.width - width / 2
            }

            MouseArea {
                anchors.fill: parent
                function pick(mx) {
                    root.hue = Math.max(0, Math.min(1, mx / width)) * 360;
                    root._commit();
                }
                onPressed: mouse => pick(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        pick(mouse.x);
                }
            }
        }

        // --- Hex entry + eyedropper --------------------------------------
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width - eyedropperBtn.width - parent.spacing
                height: 32
                radius: Colors.radiusSmall
                color: Colors.surfaceHigh
                anchors.verticalCenter: parent.verticalCenter

                TextInput {
                    id: hexInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.text
                    font.family: Config.fontFamily
                    font.pixelSize: Config.fontSize
                    selectByMouse: true

                    // A plain `text: root.value.toString()` binding gets torn
                    // out the moment the user types a character (any
                    // imperative write to `text`, including the input
                    // method's own, permanently severs a declarative
                    // binding) — after that, external picks (eyedropper,
                    // swatches, SV square) would stop reaching the field.
                    // Syncing imperatively, skipped while the field has
                    // focus, keeps external updates flowing without
                    // fighting active typing.
                    function syncFromValue() {
                        if (!hexInput.activeFocus)
                            hexInput.text = root.value.toString();
                    }

                    Component.onCompleted: hexInput.syncFromValue()
                    Connections {
                        target: root
                        function onValueChanged() {
                            hexInput.syncFromValue();
                        }
                    }

                    onEditingFinished: {
                        const c = Qt.color(text.trim());
                        if (c.a > 0 || text.trim().length > 0) {
                            root._internalUpdate = true;
                            root.value = c;
                            root._internalUpdate = false;
                            root.colorChosen(c);
                        }
                        hexInput.text = root.value.toString();
                    }
                }
            }

            IconButton {
                id: eyedropperBtn
                icon: "colorize"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root._pickFromScreen()
            }
        }

        // --- Recent swatches ---------------------------------------------
        Row {
            width: parent.width
            spacing: 8
            visible: root.recentColors.length > 0

            Repeater {
                model: root.recentColors
                Rectangle {
                    required property string modelData
                    width: 22
                    height: 22
                    radius: 11
                    color: modelData
                    border.width: root.value.toString() === modelData ? 2 : 0
                    border.color: Colors.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const c = Qt.color(parent.modelData);
                            root._internalUpdate = true;
                            root.value = c;
                            root._internalUpdate = false;
                            root.colorChosen(c);
                        }
                    }
                }
            }
        }
    }

    // --- Eyedropper: slurp -p for a point, grim for a 1x1 pixel sample ----
    function _pickFromScreen() {
        pointPicker.running = false;
        pointPicker.running = true;
    }

    property Process pointPicker: Process {
        property string point: ""
        command: ["sh", "-c", "exec slurp -p -f '%x,%y' < /dev/null"]
        stdout: SplitParser {
            onRead: line => pointPicker.point = line.trim()
        }
        onExited: exitCode => {
            if (exitCode === 0 && pointPicker.point.length > 0) {
                pixelSampler.command = ["sh", "-c", "grim -g \"$0 1x1\" -t ppm -", pointPicker.point];
                pixelSampler.running = false;
                pixelSampler.running = true;
            }
            pointPicker.point = "";
        }
    }

    // PPM (P6) format: a short ASCII header ("P6\nW H\n255\n") followed
    // immediately by raw RGB bytes — for a 1x1 sample that's exactly one
    // RGB triplet right after the last header newline. Reading via `text`
    // decodes stdout as UTF-8, which corrupts any byte >= 0x80 (about half
    // of all possible channel values) into a replacement character — `data`
    // is the raw QByteArray and survives the round trip intact.
    property Process pixelSampler: Process {
        command: ["true"]
        stdout: StdioCollector {
            id: pixelOutput
            onStreamFinished: {
                const bytes = new Uint8Array(pixelOutput.data);
                let newlines = 0, i = 0;
                for (; i < bytes.length && newlines < 3; i++) {
                    if (bytes[i] === 10)
                        newlines++;
                }
                if (i + 2 < bytes.length) {
                    const r = bytes[i];
                    const g = bytes[i + 1];
                    const b = bytes[i + 2];
                    const c = Qt.rgba(r / 255, g / 255, b / 255, 1);
                    root._internalUpdate = true;
                    root.value = c;
                    root._internalUpdate = false;
                    root.colorChosen(c);
                }
            }
        }
    }
}
