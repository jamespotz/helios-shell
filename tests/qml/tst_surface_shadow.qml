import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    TestCase { id: raster; name: "GlassCorners"; when: false }

    Window {
        id: host
        visible: true
        width: 400
        height: 160

        SurfaceShadow {
            id: shadow
            x: 20
            y: 90
            width: 160
            height: 40
            cornerRadius: 18
        }
        LiquidGlassSurface {
            id: glass
            x: 20
            y: 20
            // Odd device-pixel width with a fractional logical width at 125%.
            width: 197 / host.devicePixelRatio
            height: 32
            active: true
            cornerRadius: 16
        }
    }

    Timer {
        interval: 350
        running: true
        onTriggered: {
            const shot = raster.grabImage(host.contentItem);
            const scale = host.devicePixelRatio;
            const left = Math.round(glass.x * scale);
            const top = Math.round(glass.y * scale);
            const width = Math.round(glass.width * scale);
            const height = Math.round(glass.height * scale);
            const bg = shot.red(left - 2, top + Math.floor(height / 2));
            // Each row's cap must start as far in from the right edge as from
            // the left (within a pixel of rasterizer snapping); a truncated
            // right cap reaches the edge rows earlier than the left does.
            let capDifference = 0;
            for (let y = 0; y < height; y++) {
                let l = 0, r = 0;
                while (l < width / 2 && shot.red(left + l, top + y) >= bg - 8) l++;
                while (r < width / 2 && shot.red(left + width - 1 - r, top + y) >= bg - 8) r++;
                capDifference = Math.max(capDifference, Math.abs(l - r));
            }
            const bodyVisible = shot.red(left + Math.floor(width / 2), top + Math.floor(height / 2)) < shot.red(left, top);
            if (shadow.cornerRadius === 18 && shadow.glowRadius > 0 && bodyVisible && capDifference <= 1)
                console.warn("SURFACE_SHADOW_TEST_PASS");
            else
                console.error("SURFACE_SHADOW_TEST_FAIL", "glass cap difference:", capDifference);
            root.terminator.running = true;
        }
    }
}
