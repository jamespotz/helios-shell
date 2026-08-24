import QtQuick

// Experimental translucent surface: Hyprland supplies the blur (see the
// `layerrule blur` registered in shell.qml for the "helios:bar" namespace);
// this canvas only paints a neutral glass tint + rim light on top of it, and
// falls back to a flat fill when liquid glass is off. Fully rounded on all
// four corners — the island floats as a pill rather than sitting flush
// against the screen edge.
Canvas {
    id: root

    property bool active: false
    property real cornerRadius: 8
    property color fallbackColor: "#14121a"
    property real glassAmount: active ? 1 : 0

    antialiasing: true

    function traceBody(context, inset) {
        const left = inset;
        const top = inset;
        const right = Math.max(left, width - inset);
        const bottom = Math.max(top, height - inset);
        const r = Math.max(0, Math.min(root.cornerRadius - inset,
                                        (right - left) / 2,
                                        (bottom - top) / 2));

        context.beginPath();
        context.moveTo(left + r, top);
        context.lineTo(right - r, top);
        context.quadraticCurveTo(right, top, right, top + r);
        context.lineTo(right, bottom - r);
        context.quadraticCurveTo(right, bottom, right - r, bottom);
        context.lineTo(left + r, bottom);
        context.quadraticCurveTo(left, bottom, left, bottom - r);
        context.lineTo(left, top + r);
        context.quadraticCurveTo(left, top, left + r, top);
        context.closePath();
    }

    function paintFallback(context) {
        if (root.glassAmount >= 0.999)
            return;

        context.save();
        root.traceBody(context, 0);
        context.globalAlpha = 1 - root.glassAmount;
        context.fillStyle = root.fallbackColor;
        context.fill();
        context.restore();
    }

    function paintGlass(context) {
        if (root.glassAmount <= 0.001)
            return;

        context.save();
        root.traceBody(context, 0);
        context.clip();
        context.globalAlpha = root.glassAmount;

        // The pane stays mostly opaque. Its only variation is neutral alpha:
        // Hyprland supplies the pixels and blur underneath this surface.
        const body = context.createLinearGradient(0, 0, width, height);
        body.addColorStop(0, "rgba(20, 18, 26, 0.86)");
        body.addColorStop(0.48, "rgba(14, 12, 18, 0.82)");
        body.addColorStop(1, "rgba(24, 21, 30, 0.85)");
        context.fillStyle = body;
        context.fillRect(0, 0, width, height);

        // Remove alpha from a broad inner edge so a sharper copy of the real
        // background shows beside the blurred centre, reading as a curved rim.
        context.globalCompositeOperation = "destination-out";
        root.traceBody(context, 3.1);
        context.lineWidth = 6.2;
        context.strokeStyle = "rgba(0, 0, 0, 0.22)";
        context.stroke();

        root.traceBody(context, 1.25);
        context.lineWidth = 1.7;
        context.strokeStyle = "rgba(0, 0, 0, 0.12)";
        context.stroke();

        context.globalCompositeOperation = "source-over";

        // Neutral Fresnel-style reflection outlining the curved edge.
        root.traceBody(context, 0.7);
        context.lineWidth = 1.1;
        const rim = context.createLinearGradient(0, 0, width, height);
        rim.addColorStop(0, "rgba(255, 255, 255, 0.34)");
        rim.addColorStop(0.32, "rgba(255, 255, 255, 0.10)");
        rim.addColorStop(0.68, "rgba(255, 255, 255, 0.025)");
        rim.addColorStop(1, "rgba(255, 255, 255, 0.16)");
        context.strokeStyle = rim;
        context.stroke();

        root.traceBody(context, 4.6);
        context.lineWidth = 1.0;
        const depth = context.createLinearGradient(0, 0, width, height);
        depth.addColorStop(0, "rgba(255, 255, 255, 0.07)");
        depth.addColorStop(0.55, "rgba(0, 0, 0, 0.03)");
        depth.addColorStop(1, "rgba(0, 0, 0, 0.32)");
        context.strokeStyle = depth;
        context.stroke();

        context.restore();
    }

    onPaint: {
        const context = getContext("2d");

        context.reset();
        context.clearRect(0, 0, width, height);
        root.paintFallback(context);
        root.paintGlass(context);
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onFallbackColorChanged: requestPaint()
    onGlassAmountChanged: requestPaint()

    Behavior on glassAmount {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
}
