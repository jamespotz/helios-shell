import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    property int scenario: -1
    readonly property var designs: ["classic", "studio", "minimal", "sleeve"]
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer finish: Timer { interval: 100; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.data || item.children || []) { const result = root.find(child, name); if (result) return result; }
        return null;
    }
    function nextScenario() {
        root.scenario++;
        if (root.scenario === root.designs.length * 6) {
            console.warn("TURNTABLE_DESIGNS_TEST_PASS"); root.finish.start();
            return;
        }
        Config.setOption("reducedMotion", true);
        Config.setOption("turntableDesign", root.designs[Math.floor(root.scenario / 6)]);
        Config.setOption("turntableScale", root.scenario % 6 < 3 ? 80 : 120);
        Config.setOption("turntablePlatter", "aurora");
        turntable.playing = root.scenario % 3 !== 0;
        turntable.progress = root.scenario % 3 === 2 ? 1 : 0;
        advance.restart();
    }
    FloatingWindow {
        visible: true
        implicitWidth: 450
        implicitHeight: 400
        color: Colors.background
        Item {
            id: surface
            anchors.fill: parent
            Turntable { id: turntable; anchors.centerIn: parent; size: 160; artUrl: Qt.resolvedUrl("data/linux.svg") }
        }
    }
    Timer {
        id: advance
        interval: 160
        running: true
        onTriggered: {
            try {
                if (root.scenario >= 0) {
                    const design = root.designs[Math.floor(root.scenario / 6)];
                    const record = root.find(turntable, "turntableRecord");
                    const base = root.find(turntable, "turntableBase");
                    const arm = root.find(turntable, "turntableTonearm");
                    const label = design + " scenario " + root.scenario;
                    root.verify(Config.turntableDesign === design, "design selected: " + label);
                    const hasDeck = design === "classic" || design === "studio";
                    root.verify(base.visible === hasDeck, "deck visibility: " + label);
                    const deckButtons = root.find(turntable, "turntableDeckButtons");
                    root.verify(deckButtons && deckButtons.visible === hasDeck, "decorative buttons only on decks: " + label);
                    if (hasDeck) {
                        for (const name of ["turntableDeckPower", "turntableDeckKey_0", "turntableDeckKey_1"]) {
                            const button = root.find(turntable, name);
                            root.verify(button, "deck button present: " + name);
                            const corner = button.mapToItem(turntable, 0, 0);
                            root.verify(corner.x >= 0 && corner.y >= 0 && corner.x + button.width <= turntable.width
                                && corner.y + button.height <= turntable.height, "button within deck: " + label);
                            const dx = Math.max(corner.x - record.x - record.width / 2,
                                0, record.x + record.width / 2 - corner.x - button.width);
                            const dy = Math.max(corner.y - record.y - record.height / 2,
                                0, record.y + record.height / 2 - corner.y - button.height);
                            root.verify(dx * dx + dy * dy > record.width * record.width / 4, "button clears platter: " + label);
                            root.verify(!button.activeFocusOnTab, "decorative button excluded from keyboard navigation: " + label);
                        }
                    }
                    root.verify(design === "studio" || design === "sleeve" ? turntable.width > turntable.height : turntable.width === turntable.height, "design layout dimensions: " + label);
                    root.verify(record.x >= 0 && record.y >= 0 && record.x + record.width <= turntable.width
                        && record.y + record.height <= turntable.height, "record stays within layout: " + label);
                    root.verify(design !== "studio" || record.x + record.width / 2 < turntable.width / 2, "Studio platter offset left: " + label);
                    root.verify(Math.abs(record.width - (root.scenario % 6 < 3 ? 128 : 192)) < 0.001, "shared size setting: " + label);
                    root.verify(record.gradient && arm.visible, "color and tonearm preferences retained: " + label);
                    root.verify(!root.find(turntable, "turntableMotion").running, "reduced motion applies: " + label);
                    const sleeve = root.find(turntable, "turntableSleeveArtwork");
                    root.verify(sleeve && sleeve.visible === (design === "sleeve"), "album sleeve only shown in Sleeve design: " + label);
                    if (design === "sleeve") {
                        root.verify(sleeve.width === sleeve.height && sleeve.rotation === 0, "square album sleeve stays still: " + label);
                        root.verify(sleeve.x + sleeve.width > record.x + record.width / 2
                            && sleeve.x + sleeve.width < record.x + record.width, "album sleeve overlaps left half of vinyl: " + label);
                        root.verify(sleeve.x >= 0 && sleeve.y >= 0 && sleeve.x + sleeve.width <= turntable.width
                            && sleeve.y + sleeve.height <= turntable.height, "album sleeve stays within layout: " + label);
                        root.verify(root.find(turntable, "turntableSleeveImage").status === Image.Ready, "album artwork loads in sleeve: " + label);
                    }
                    if (design === "studio" || design === "sleeve") {
                        if (turntable.playing) {
                            const cartridge = arm.children[arm.children.length - 1];
                            const tip = cartridge.mapToItem(turntable, cartridge.width / 2, cartridge.height);
                            const dx = tip.x - record.x - record.width / 2;
                            const dy = tip.y - record.y - record.height / 2;
                            root.verify(dx * dx + dy * dy <= record.width * record.width / 4,
                                "cartridge sits on record during playback: " + label);
                        }
                        for (const part of arm.children) {
                            for (const point of [[0, 0], [part.width, 0], [0, part.height], [part.width, part.height]]) {
                                const mapped = part.mapToItem(turntable, point[0], point[1]);
                                root.verify(mapped.x >= 0 && mapped.y >= 0 && mapped.x <= turntable.width && mapped.y <= turntable.height,
                                    "tonearm stays within layout: " + label);
                            }
                        }
                    }
                    if (Quickshell.env("HELIOS_TURNTABLE_DESIGN_CAPTURE") && root.scenario % 6 === 1) {
                        const path = Quickshell.env("HELIOS_TURNTABLE_DESIGN_CAPTURE") + "/" + design + ".png";
                        surface.grabToImage(result => { result.saveToFile(path); root.nextScenario(); });
                        return;
                    }
                }
                root.nextScenario();
            } catch (error) {
                advance.stop(); console.error("TURNTABLE_DESIGNS_TEST_FAIL", error.toString()); root.finish.start();
            }
        }
    }
}
