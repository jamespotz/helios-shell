import QtQuick
import "../../services"

// Miniature weather effect for the island's conditions card — same concept
// as the full wallpaper WeatherEffect but with fewer particles and lower
// opacity to stay legible behind text content.
Item {
    id: root
    anchors.fill: parent

    readonly property string effect: {
        if (!Weather.available) return "none";
        const c = Weather.condition.toLowerCase();
        if (c.includes("thunder")) return "storm";
        if (c.includes("heavy rain") || c.includes("violent")) return "heavyrain";
        if (c.includes("rain") || c.includes("drizzle") || c.includes("shower")) return "rain";
        if (c.includes("snow") || c.includes("sleet") || c.includes("ice") || c.includes("grains")) return "snow";
        if (c.includes("fog") || c.includes("mist") || c.includes("haze")) return "fog";
        return "none";
    }

    visible: effect !== "none"
    opacity: visible ? 0.6 : 0
    Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

    // --- Rain ---------------------------------------------------------------
    Canvas {
        id: rainCanvas
        anchors.fill: parent
        visible: root.effect === "rain" || root.effect === "heavyrain" || root.effect === "storm"

        readonly property int dropCount: root.effect === "heavyrain" || root.effect === "storm" ? 30 : 15
        property var drops: []

        onVisibleChanged: if (visible) initDrops()
        Component.onCompleted: if (visible) initDrops()

        function initDrops() {
            const d = [];
            for (let i = 0; i < dropCount; i++) {
                d.push({
                    x: Math.random() * width,
                    y: Math.random() * height,
                    speed: 2 + Math.random() * 3,
                    length: 8 + Math.random() * 12,
                    opacity: 0.2 + Math.random() * 0.3
                });
            }
            drops = d;
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (drops.length === 0) return;

            for (let i = 0; i < drops.length; i++) {
                const d = drops[i];
                ctx.strokeStyle = Qt.rgba(0.7, 0.8, 0.9, d.opacity);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(d.x, d.y);
                ctx.lineTo(d.x + 0.1 * d.length, d.y + d.length);
                ctx.stroke();

                d.y += d.speed;
                d.x += 0.1 * d.speed;
                if (d.y > height) {
                    d.y = -d.length;
                    d.x = Math.random() * width;
                }
            }
        }

        Timer {
            running: rainCanvas.visible
            interval: 33
            repeat: true
            onTriggered: rainCanvas.requestPaint()
        }
    }

    // --- Snow ---------------------------------------------------------------
    Canvas {
        id: snowCanvas
        anchors.fill: parent
        visible: root.effect === "snow"

        readonly property int flakeCount: 12
        property var flakes: []

        onVisibleChanged: if (visible) initFlakes()
        Component.onCompleted: if (visible) initFlakes()

        function initFlakes() {
            const f = [];
            for (let i = 0; i < flakeCount; i++) {
                f.push({
                    x: Math.random() * width,
                    y: Math.random() * height,
                    radius: 1 + Math.random() * 2,
                    speed: 0.3 + Math.random() * 0.8,
                    drift: (Math.random() - 0.5) * 0.5,
                    wobble: Math.random() * Math.PI * 2,
                    opacity: 0.5 + Math.random() * 0.4
                });
            }
            flakes = f;
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (flakes.length === 0) return;

            for (let i = 0; i < flakes.length; i++) {
                const f = flakes[i];
                ctx.fillStyle = Qt.rgba(1, 1, 1, f.opacity);
                ctx.beginPath();
                ctx.arc(f.x, f.y, f.radius, 0, Math.PI * 2);
                ctx.fill();

                f.y += f.speed;
                f.x += f.drift + Math.sin(f.wobble) * 0.2;
                f.wobble += 0.02;
                if (f.y > height + f.radius) {
                    f.y = -f.radius * 2;
                    f.x = Math.random() * width;
                }
            }
        }

        Timer {
            running: snowCanvas.visible
            interval: 33
            repeat: true
            onTriggered: snowCanvas.requestPaint()
        }
    }

    // --- Fog ----------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        visible: root.effect === "fog"
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(0.85, 0.88, 0.9, 0.2) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // --- Lightning flash (storm only) ---------------------------------------
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
        visible: root.effect === "storm"

        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flash; property: "opacity"; to: 0.4; duration: 40 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 100 }
        }

        Timer {
            running: flash.visible
            repeat: true
            interval: 5000 + Math.random() * 7000
            onTriggered: {
                interval = 5000 + Math.random() * 7000;
                flashAnim.restart();
            }
        }
    }
}
