import QtQuick

// Apple-style vibrancy surface: Hyprland supplies the real blur (via
// `layerrule blur` for the "helios:bar" namespace in shell.qml); this
// Canvas only paints a neutral tint + subtle specular rim on top.
// Falls back to a flat fill when liquid glass is disabled.
//
// Design principle: Apple's dark vibrancy materials are almost entirely
// neutral gray with very slight warmth — no colored tints. The blur
// itself provides the color from what's behind.
Canvas {
    id: root

    property bool active: false
    property real cornerRadius: 8
    property color fallbackColor: "#1c1c1e"
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

        // Neutral dark tint — Apple vibrancy is almost monochrome gray,
        // letting the blurred wallpaper underneath provide color.
        const body = context.createLinearGradient(0, 0, 0, height);
        body.addColorStop(0, "rgba(38, 38, 40, 0.72)");
        body.addColorStop(1, "rgba(28, 28, 30, 0.78)");
        context.fillStyle = body;
        context.fillRect(0, 0, width, height);

        // Subtle vignette darkening at the bottom edge — adds depth
        // without being distracting.
        const vignette = context.createLinearGradient(0, height * 0.6, 0, height);
        vignette.addColorStop(0, "rgba(0, 0, 0, 0)");
        vignette.addColorStop(1, "rgba(0, 0, 0, 0.08)");
        context.fillStyle = vignette;
        context.fillRect(0, 0, width, height);

        context.globalCompositeOperation = "source-over";

        // Top-edge specular highlight — a single clean line, the way Apple
        // dark materials catch ambient light at the top.
        root.traceBody(context, 0.5);
        context.lineWidth = 0.75;
        const rim = context.createLinearGradient(0, 0, width, 0);
        rim.addColorStop(0, "rgba(255, 255, 255, 0.08)");
        rim.addColorStop(0.3, "rgba(255, 255, 255, 0.18)");
        rim.addColorStop(0.7, "rgba(255, 255, 255, 0.18)");
        rim.addColorStop(1, "rgba(255, 255, 255, 0.08)");
        context.strokeStyle = rim;
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
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
}
