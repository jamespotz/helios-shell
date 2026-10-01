import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services"
import "../../components"

// The Dock: pinned and running apps, centered on the bottom, left or right
// edge of each screen. By default it hides while a window on the screen's
// active workspace would sit under it, and reveals when the pointer
// reaches that edge.
PanelWindow {
    id: dock

    required property var modelData
    screen: modelData

    readonly property string position: Dock.position
    readonly property bool vertical: dock.position !== "bottom"
    // +1 when "away from the edge" is the positive axis direction (left
    // edge → rightwards); -1 for the bottom and right edges.
    readonly property int outward: dock.position === "left" ? 1 : -1
    // Magnified icons grow away from the screen edge.
    readonly property int growOrigin: dock.position === "left" ? Item.Left : dock.position === "right" ? Item.Right : Item.Bottom

    readonly property int iconSize: Dock.iconSize
    readonly property int iconSpacing: Dock.iconSpacing
    readonly property int bodyPad: Dock.edgePadding
    // Decode icons at the largest size they're drawn (magnified, in device
    // pixels) so small icons stay sharp instead of being scaled from 128px.
    readonly property int iconSourceSize: Math.ceil((dock.iconSize - 4) * dock.magnifyScale * (dock.modelData.devicePixelRatio || 1))
    readonly property int edgeGap: Dock.edgeGap
    readonly property int revealStrip: Dock.revealStrip
    readonly property real magnifyScale: Dock.magnifyScale
    readonly property int slot: dock.iconSize + dock.iconSpacing
    // Body size along the Dock (main axis) and across it (thickness).
    readonly property int bodyLength: (dock.vertical ? iconRow.implicitHeight : iconRow.implicitWidth) + dock.bodyPad * 2
    readonly property int bodyThickness: dock.iconSize + dock.bodyPad * 2
    readonly property int separatorLength: 9
    // The separator before the trailing buttons.
    readonly property bool separatorShown: dock.items.length > 0 && dock.buttons.length > 0
    // All Applications, Settings and Trash, after the items. hoveredIndex
    // for a button is items.length + its `slot`, whether or not the others
    // show.
    readonly property var buttons: [
        { slot: 0, icon: "apps", label: "All Applications", shown: Dock.showAppsButton },
        { slot: 1, icon: "settings", label: "Settings", shown: Dock.showSettingsButton },
        { slot: 2, icon: "delete", label: "Trash", shown: Dock.showTrash }
    ].filter(button => button.shown)
    function buttonAt(index) { return dock.buttons.find(button => button.slot === index - dock.items.length) || null; }
    function cellLength(item) { return item && item.separator ? dock.separatorLength : dock.iconSize; }
    // Start of each item's cell along iconRow; the extra last entry is
    // where the items end.
    readonly property var cellStarts: {
        const starts = [];
        let at = 0;
        for (const item of dock.items) {
            starts.push(at);
            at += dock.cellLength(item) + dock.iconSpacing;
        }
        starts.push(at);
        return starts;
    }

    readonly property var items: Dock.scopedItems(Dock.items, dock.modelData.name)
    readonly property int pinnedCount: dock.items.filter(item => item.pinned).length

    // Right-click menu target; null = closed.
    property var menuItem: null
    property int menuIndex: -1
    property int hoveredIndex: -1
    readonly property var hoveredItem: dock.hoveredIndex >= 0 && dock.hoveredIndex < dock.items.length ? dock.items[dock.hoveredIndex] : null

    // Window previews: opened after a short hover on a running app, kept
    // open while the pointer is on the icon or the previews themselves.
    property string previewKey: ""
    readonly property var previewItem: dock.previewKey ? dock.items.find(item => item.key === dock.previewKey && item.windows.length > 0) || null : null
    readonly property int previewIndex: dock.previewItem ? dock.items.indexOf(dock.previewItem) : -1

    // Drag reorder: the dragged icon follows the pointer; the others make
    // room at dropIndex. Pins are only rewritten on release.
    property int dragIndex: -1
    property real dragDelta: 0
    // Cells vary in length (separators are narrow), so the dragged cell
    // moves past a neighbor once its center is nearer the spot it would
    // take there than the one it holds.
    readonly property int dropIndex: {
        if (dock.dragIndex < 0) return -1;
        const items = dock.items;
        const starts = dock.cellStarts;
        const from = dock.dragIndex;
        const dragged = items[from];
        const length = dock.cellLength(dragged);
        const end = index => starts[index] + dock.cellLength(items[index]);
        const center = starts[from] + length / 2 + dock.dragDelta;
        let target = from;
        while (target + 1 < items.length && center > (end(target) + end(target + 1)) / 2 - length / 2) target++;
        if (target === from)
            while (target > 0 && center < (starts[target - 1] + starts[target]) / 2 + length / 2) target--;
        const last = dragged && dragged.pinned ? dock.pinnedCount - 1 : from;
        return Math.max(0, Math.min(target, last));
    }
    // How far the others move to make room for the dragged cell.
    readonly property real dragShift: dock.dragIndex < 0 ? 0 : dock.cellLength(dock.items[dock.dragIndex]) + dock.iconSpacing

    // Where the revealed Dock sits, in global logical coordinates.
    readonly property rect revealedRect: {
        const s = dock.modelData;
        const w = dock.vertical ? dock.bodyThickness : dock.bodyLength;
        const h = dock.vertical ? dock.bodyLength : dock.bodyThickness;
        const along = Dock.alignmentOffset(dock.vertical ? s.height : s.width, dock.vertical ? h : w);
        if (dock.position === "left") return Qt.rect(s.x + dock.edgeGap, s.y + along, w, h);
        if (dock.position === "right") return Qt.rect(s.x + s.width - dock.edgeGap - w, s.y + along, w, h);
        return Qt.rect(s.x + along, s.y + s.height - dock.edgeGap - h, w, h);
    }
    readonly property bool overlapped: Dock.autohide === "intellihide" && Dock.overlaps(dock.modelData.name, dock.revealedRect)
    readonly property var hyprMonitor: Hyprland.monitorFor(dock.modelData)
    readonly property bool hasFullscreen: !!dock.hyprMonitor && !!dock.hyprMonitor.activeWorkspace && dock.hyprMonitor.activeWorkspace.hasFullscreen
    // Over a fullscreen window the Dock only shows on screen-edge hover.
    readonly property bool overFullscreen: dock.hasFullscreen && Dock.overFullscreen === "reveal"
    property bool hoverHold: false
    readonly property bool revealed: (!dock.hasFullscreen && (Dock.autohide === "never"
        || (Dock.autohide === "intellihide" && !dock.overlapped)))
        || dock.hoverHold || dock.menuItem !== null || dock.dragIndex >= 0 || dock.previewItem !== null
    readonly property bool magnifying: Dock.magnify && !Config.reducedMotion && hitHover.hovered && dock.dragIndex < 0
    // Extra room a magnified icon grows away from the edge.
    readonly property real magnifyRoom: Dock.magnify && !Config.reducedMotion ? dock.iconSize * (dock.magnifyScale - 1) : 0
    readonly property real magnifyLift: dock.magnifying ? dock.magnifyRoom : 0

    visible: Dock.shownOn(dock.modelData.name)
    anchors.bottom: true
    anchors.top: dock.vertical
    anchors.left: dock.position !== "right"
    anchors.right: dock.position !== "left"
    // Room beside the Dock for tooltips, previews and the right-click
    // menu; the mask keeps everything but the Dock itself click-through.
    implicitHeight: 480
    implicitWidth: 720
    exclusiveZone: Dock.autohide === "never" ? dock.bodyThickness + dock.edgeGap : 0
    exclusionMode: Dock.autohide === "never" ? ExclusionMode.Normal : ExclusionMode.Ignore
    color: "transparent"
    // A fullscreen window covers Top; Overlay lifts the Dock above it.
    WlrLayershell.layer: dock.overFullscreen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "helios:dock"
    WlrLayershell.keyboardFocus: dock.menuItem ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: hitArea
        Region { item: menu }
        Region { item: preview }
    }

    // Center of the cell at index along the Dock, in window coordinates.
    // The buttons (index >= items.length) sit past the separator.
    function anchorFor(index) {
        const base = (dock.vertical ? dockArea.y : dockArea.x) + dock.bodyPad;
        if (index < dock.items.length)
            return base + dock.cellStarts[index] + dock.cellLength(dock.items[index]) / 2;
        const at = dock.cellStarts[dock.items.length] + (dock.separatorShown ? dock.separatorLength + dock.iconSpacing : 0)
            + Math.max(0, dock.buttons.indexOf(dock.buttonAt(index))) * dock.slot;
        return base + at + dock.iconSize / 2;
    }
    // Top-left for a popup of size w×h beside the icon at index, clearance
    // px further out than the Dock's outer face.
    function popupPos(w, h, index, clearance) {
        const along = dock.anchorFor(index);
        if (!dock.vertical)
            return Qt.point(Math.max(8, Math.min(along - w / 2, dock.width - w - 8)), dockArea.y + body.y - h - 8 - clearance);
        const y = Math.max(8, Math.min(along - h / 2, dock.height - h - 8));
        return dock.position === "left"
            ? Qt.point(dockArea.x + body.x + body.width + 8 + clearance, y)
            : Qt.point(dockArea.x + body.x - w - 8 - clearance, y);
    }
    // Icon scale for an icon centered at `along` (iconRow coordinates).
    function magnification(along) {
        if (!dock.magnifying) return 1;
        const pointer = (dock.vertical ? hitHover.point.position.y : hitHover.point.position.x) - dock.bodyPad;
        const t = Math.min(1, Math.abs(along - pointer) / (dock.slot * 2.5));
        return 1 + (dock.magnifyScale - 1) * (Math.cos(Math.PI * t) + 1) / 2;
    }
    function openMenu(index) {
        dock.previewKey = "";
        dock.menuIndex = index;
        dock.menuItem = dock.items[index];
        // Right-clicking gave the Dock keyboard focus (OnDemand); hand it to
        // the menu for Esc / arrows / Enter.
        menu.forceActiveFocus();
    }
    function menuEntries(item) {
        if (!item) return [];
        if (item.separator) return [{ label: "Remove Separator", run: () => Dock.unpin(item.key) }];
        const entries = item.entry ? (item.entry.actions || []).map(action => ({
            label: action.name, run: () => Launcher.runDesktopAction(action, item.name)
        })) : [];
        if (item.entry)
            entries.push({ label: item.pinned ? "Remove from Dock" : "Keep in Dock", run: () => item.pinned ? Dock.unpin(item.key) : Dock.pin(item.key) });
        if (item.pinned)
            entries.push({ label: "Add Separator After", run: () => Dock.addSeparator(Dock.pins.indexOf(item.key) + 1) });
        if (item.windows.some(window => Dock.isMinimized(window)))
            entries.push({ label: "Restore", run: () => Dock.restore(item) });
        else if (item.windows.length > 0)
            entries.push({ label: "Minimize", run: () => Dock.minimize(item) });
        if (item.windows.length > 0)
            entries.push({ label: item.windows.length > 1 ? "Close " + item.windows.length + " Windows" : "Close Window", danger: true, run: () => Dock.closeWindows(item) });
        return entries;
    }
    function finishDrag() {
        const dragged = dock.items[dock.dragIndex];
        const target = dock.dropIndex;
        if (dragged && (dragged.pinned ? target !== dock.dragIndex : target < dock.dragIndex))
            Dock.placeAt(dragged.key, Math.min(target, dock.pinnedCount));
        dock.dragIndex = -1;
        dock.dragDelta = 0;
    }

    onHoveredItemChanged: {
        const running = dock.hoveredItem && dock.hoveredItem.windows.length > 0 && Dock.previews;
        if (dock.previewItem) {
            // Already previewing: follow the pointer across running apps.
            if (running) dock.previewKey = dock.hoveredItem.key;
            else if (dock.hoveredIndex >= 0) dock.previewKey = "";
            else previewClose.restart();
        } else if (running) {
            previewOpen.restart();
        } else {
            previewOpen.stop();
        }
    }

    Timer {
        id: hideDelay
        interval: Dock.hideDelay
        onTriggered: dock.hoverHold = false
    }
    Timer {
        id: previewOpen
        interval: 450
        onTriggered: {
            if (dock.hoveredItem && dock.hoveredItem.windows.length > 0 && dock.menuItem === null && dock.dragIndex < 0)
                dock.previewKey = dock.hoveredItem.key;
        }
    }
    Timer {
        id: previewClose
        interval: Config.hoverCollapseDelay
        onTriggered: if (dock.hoveredIndex < 0 && !preview.hovered) dock.previewKey = ""
    }
    Connections {
        target: preview
        function onHoveredChanged() { if (!preview.hovered) previewClose.restart(); }
    }

    // Click-outside closes the menu. The grab starts just after the menu
    // opens (same as Bar.qml): grabbing before Hyprland has the menu in the
    // input region clears it immediately.
    HyprlandFocusGrab {
        id: menuGrab
        windows: [dock]
        active: false
        onCleared: dock.menuItem = null
    }
    Timer {
        id: menuGrabDelay
        interval: 80
        onTriggered: menuGrab.active = true
    }
    onMenuItemChanged: {
        if (dock.menuItem) {
            menuGrabDelay.restart();
        } else {
            menuGrabDelay.stop();
            menuGrab.active = false;
        }
    }

    // Holds the Dock plus the room magnified icons grow into, so one
    // HoverHandler sees the pointer over every icon. Input only arrives
    // inside hitArea (the mask).
    Item {
        id: dockArea
        readonly property real depth: dock.bodyThickness + dock.edgeGap + dock.magnifyRoom
        width: dock.vertical ? dockArea.depth : dock.bodyLength
        height: dock.vertical ? dock.bodyLength : dockArea.depth
        x: dock.position === "left" ? 0 : dock.position === "right" ? dock.width - width : Dock.alignmentOffset(dock.width, width)
        y: dock.vertical ? Dock.alignmentOffset(dock.height, height) : dock.height - height

        HoverHandler {
            id: hitHover
            onHoveredChanged: {
                if (hovered) {
                    hideDelay.stop();
                    dock.hoverHold = true;
                } else {
                    hideDelay.restart();
                }
            }
        }

        // Input region: the Dock while revealed (growing with magnified
        // icons), a thin strip along the edge otherwise.
        Item {
            id: hitArea
            readonly property real depth: dock.revealed ? dock.bodyThickness + dock.edgeGap + dock.magnifyLift : dock.revealStrip
            width: dock.vertical ? hitArea.depth : parent.width
            height: dock.vertical ? parent.height : hitArea.depth
            x: dock.position === "right" ? parent.width - width : 0
            y: dock.vertical ? 0 : parent.height - height
        }

        Item {
            id: body
            // Distance of the Dock from the screen edge; negative slides it
            // off-screen.
            property real offset: dock.revealed ? dock.edgeGap : -dock.bodyThickness - 4
            width: dock.vertical ? dock.bodyThickness : dock.bodyLength
            height: dock.vertical ? dock.bodyLength : dock.bodyThickness
            x: dock.position === "left" ? body.offset
                : dock.position === "right" ? dockArea.width - body.offset - width
                : (dockArea.width - width) / 2
            y: dock.vertical ? (dockArea.height - height) / 2 : dockArea.height - body.offset - height
            opacity: dock.revealed ? 1 : 0

            Behavior on offset {
                enabled: !Config.reducedMotion && Dock.revealDuration > 0
                NumberAnimation { duration: Dock.revealDuration; easing.type: Easing.OutCubic }
            }
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            // PanelBackground's look with the fill swapped for
            // LiquidGlassSurface, same as the OSD, so the Dock follows the
            // Liquid Glass toggle (or its own override).
            Rectangle {
                id: bodyBackground
                anchors.fill: parent
                radius: Math.min(Dock.cornerRadius, Math.min(width, height) / 2)
                opacity: Dock.backgroundOpacity
                color: "transparent"

                // The shadow would darken the translucent glass tint.
                SurfaceShadow {
                    anchors.fill: parent
                    z: -1
                    cornerRadius: bodyBackground.radius
                    visible: !Dock.glassActive
                    glowRadius: Dock.shadowGlowRadius
                    spread: Dock.shadowSpread
                }

                LiquidGlassSurface {
                    anchors.fill: parent
                    z: -1
                    active: Dock.glassActive
                    cornerRadius: bodyBackground.radius
                    fallbackColor: Qt.alpha(Colors.surface, Colors.panelOpacity)
                }
            }

            SurfaceBorder {
                anchors.fill: parent
                visible: Dock.border
                radius: bodyBackground.radius
                border.width: Dock.borderWidth
                tint: Dock.borderColor
                tintOpacity: Dock.borderOpacity
            }

            Grid {
                id: iconRow
                readonly property int cells: dock.items.length + dock.buttons.length + (dock.separatorShown ? 1 : 0)
                anchors.centerIn: parent
                rows: dock.vertical ? Math.max(1, iconRow.cells) : 1
                columns: dock.vertical ? 1 : Math.max(1, iconRow.cells)
                rowSpacing: dock.iconSpacing
                columnSpacing: dock.iconSpacing
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                Repeater {
                    model: dock.items

                    delegate: Item {
                        id: iconCell
                        required property var modelData
                        required property int index

                        readonly property bool dragged: dock.dragIndex === iconCell.index
                        readonly property bool separator: !!iconCell.modelData.separator
                        readonly property bool focusedApp: Hyprland.activeToplevel !== null
                            && iconCell.modelData.windows.some(window => window.toplevel === Hyprland.activeToplevel)
                        readonly property bool minimized: iconCell.modelData.windows.length > 0
                            && iconCell.modelData.windows.every(window => Dock.isMinimized(window))
                        readonly property int badge: Dock.badges[iconCell.modelData.key] || 0
                        readonly property real shift: dock.dragIndex < 0 || iconCell.dragged ? 0
                            : dock.dragIndex < iconCell.index && iconCell.index <= dock.dropIndex ? -dock.dragShift
                            : dock.dropIndex <= iconCell.index && iconCell.index < dock.dragIndex ? dock.dragShift : 0
                        readonly property real along: dock.vertical ? iconCell.y + iconCell.height / 2 : iconCell.x + iconCell.width / 2
                        property real pressAlong: 0
                        // Set once this press becomes a drag, so its release
                        // doesn't also count as a click (finishDrag has already
                        // cleared dragIndex by the time clicked fires).
                        property bool pressDragged: false
                        // Wheel delta not yet turned into a window step
                        // (touchpads send many small deltas).
                        property real wheelRest: 0
                        // Set on launch; cleared when a window appears (the
                        // Dock rebuilds this delegate) or after a timeout.
                        property bool launching: false
                        property real bounce: 0

                        width: dock.vertical ? dock.iconSize : dock.cellLength(iconCell.modelData)
                        height: dock.vertical ? dock.cellLength(iconCell.modelData) : dock.iconSize
                        z: iconCell.dragged ? 1 : 0

                        transform: Translate {
                            readonly property real mainShift: iconCell.dragged ? dock.dragDelta : iconCell.shift
                            readonly property real crossShift: iconCell.bounce * dock.iconSize * 0.35 * dock.outward
                            x: dock.vertical ? crossShift : mainShift
                            y: dock.vertical ? mainShift : crossShift
                            Behavior on x {
                                enabled: !iconCell.dragged && !dock.vertical && !Config.reducedMotion
                                NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
                            }
                            Behavior on y {
                                enabled: !iconCell.dragged && dock.vertical && !Config.reducedMotion
                                NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
                            }
                        }

                        Timer {
                            running: iconCell.launching
                            interval: 4000
                            onTriggered: iconCell.launching = false
                        }
                        SequentialAnimation on bounce {
                            running: iconCell.launching && Dock.launchBounce && !Config.reducedMotion
                            loops: Animation.Infinite
                            onStopped: iconCell.bounce = 0
                            NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutQuad }
                            NumberAnimation { to: 0; duration: 260; easing.type: Easing.InQuad }
                        }

                        // Icon, fallback glyph and badge scale together,
                        // growing away from the screen edge.
                        Rectangle {
                            visible: iconCell.separator
                            anchors.centerIn: parent
                            width: dock.vertical ? dock.iconSize - 12 : 1
                            height: dock.vertical ? 1 : dock.iconSize - 12
                            color: Colors.outline
                            opacity: iconCell.dragged || iconMouse.containsMouse ? 1 : 0.7
                        }

                        Item {
                            id: iconVisual
                            visible: !iconCell.separator
                            anchors.fill: parent
                            transformOrigin: dock.growOrigin
                            scale: (iconMouse.pressed && !iconCell.dragged && !Config.reducedMotion ? 0.9 : 1)
                                * dock.magnification(iconCell.along)
                            opacity: iconCell.minimized ? 0.6 : 1
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: appIcon.source.toString() === ""
                                icon: "deployed_code"
                                font.pixelSize: dock.iconSize - 12
                                // Scaled by magnification: distance-field
                                // text stays sharp, native glyphs pixelate.
                                renderType: Text.QtRendering
                                color: Colors.subtext
                            }

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: dock.iconSize - 4
                                height: dock.iconSize - 4
                                source: Quickshell.iconPath(iconCell.modelData.icon, true)
                                sourceSize: Qt.size(dock.iconSourceSize, dock.iconSourceSize)
                                mipmap: true
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                opacity: iconMouse.containsMouse || iconCell.dragged ? 1 : 0.92
                            }

                            // Notification badge — unseen notifications from
                            // this app.
                            Rectangle {
                                visible: iconCell.badge > 0 && Dock.showBadges
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: -3
                                anchors.topMargin: -3
                                width: Math.max(height, badgeText.implicitWidth + 8)
                                height: 18
                                radius: height / 2
                                color: Colors.danger

                                StyledText {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: iconCell.badge > 99 ? "99+" : iconCell.badge
                                    color: Colors.errorText
                                    font.pixelSize: Config.fontSize - 3
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        // Running indicator on the screen-edge side, styled by
                        // Dock.indicatorStyle — accent for the focused app,
                        // hollow when every window is minimized.
                        Grid {
                            id: indicator
                            readonly property int windowCount: iconCell.modelData.windows.length
                            visible: indicator.windowCount > 0 && Dock.showIndicators
                            columns: dock.vertical ? 1 : 3
                            spacing: 3
                            x: dock.position === "left" ? -width - 1 : dock.position === "right" ? parent.width + 1 : (parent.width - width) / 2
                            y: dock.vertical ? (parent.height - height) / 2 : parent.height + 1

                            Repeater {
                                model: Dock.indicatorStyle === "windows" ? Math.min(3, indicator.windowCount) : 1

                                Rectangle {
                                    readonly property real length: Dock.indicatorStyle === "line" ? Math.round(dock.iconSize * 0.4)
                                        : Dock.indicatorStyle === "dot" && indicator.windowCount > 1 ? 10 : 4
                                    width: dock.vertical ? 4 : length
                                    height: dock.vertical ? length : 4
                                    radius: 2
                                    color: iconCell.minimized ? "transparent" : iconCell.focusedApp ? Colors.accent : Colors.subtext
                                    border.width: iconCell.minimized ? 1 : 0
                                    border.color: Colors.subtext
                                    Behavior on width { NumberAnimation { duration: Config.animFast } }
                                    Behavior on height { NumberAnimation { duration: Config.animFast } }
                                }
                            }
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: iconCell.dragged ? Qt.ClosedHandCursor : iconCell.separator ? Qt.OpenHandCursor : Qt.PointingHandCursor

                            onContainsMouseChanged: {
                                if (containsMouse) dock.hoveredIndex = iconCell.index;
                                else if (dock.hoveredIndex === iconCell.index) dock.hoveredIndex = -1;
                            }
                            // Measured in iconRow coordinates: the MouseArea moves with the
                            // dragged icon, so its local mouse position would feed
                            // dragDelta back into itself and make the icon shake.
                            function alongInRow(mouse) {
                                const pos = iconMouse.mapToItem(iconRow, mouse.x, mouse.y);
                                return dock.vertical ? pos.y : pos.x;
                            }
                            onPressed: mouse => {
                                iconCell.pressAlong = iconMouse.alongInRow(mouse);
                                iconCell.pressDragged = false;
                            }
                            onPositionChanged: mouse => {
                                if (!(pressedButtons & Qt.LeftButton)) return;
                                const delta = iconMouse.alongInRow(mouse) - iconCell.pressAlong;
                                if (!iconCell.dragged && Math.abs(delta) > 6) {
                                    dock.menuItem = null;
                                    dock.previewKey = "";
                                    dock.dragIndex = iconCell.index;
                                    iconCell.pressDragged = true;
                                }
                                if (iconCell.dragged) dock.dragDelta = delta;
                            }
                            onReleased: mouse => {
                                if (iconCell.dragged) dock.finishDrag();
                            }
                            onCanceled: if (iconCell.dragged) { dock.dragIndex = -1; dock.dragDelta = 0; }
                            onWheel: wheel => {
                                if (!Dock.scrollCycle || iconCell.modelData.windows.length === 0) {
                                    wheel.accepted = false;
                                    return;
                                }
                                iconCell.wheelRest += wheel.angleDelta.y || wheel.angleDelta.x;
                                if (Math.abs(iconCell.wheelRest) < 120) return;
                                Dock.cycleWindows(iconCell.modelData, iconCell.wheelRest > 0 ? -1 : 1);
                                iconCell.wheelRest = 0;
                            }
                            onClicked: mouse => {
                                if (dock.dragIndex >= 0 || iconCell.pressDragged) return;
                                if (iconCell.separator && mouse.button !== Qt.RightButton) return;
                                if (mouse.button === Qt.RightButton)
                                    dock.openMenu(iconCell.index);
                                else if (mouse.button === Qt.MiddleButton)
                                    Dock.middleClickItem(iconCell.modelData);
                                else {
                                    dock.menuItem = null;
                                    dock.previewKey = "";
                                    previewOpen.stop();
                                    if (Dock.activate(iconCell.modelData)) iconCell.launching = true;
                                }
                            }
                        }
                    }
                }

                Item {
                    visible: dock.separatorShown
                    width: dock.vertical ? dock.iconSize : dock.separatorLength
                    height: dock.vertical ? dock.separatorLength : dock.iconSize

                    Rectangle {
                        anchors.centerIn: parent
                        width: dock.vertical ? dock.iconSize - 12 : 1
                        height: dock.vertical ? 1 : dock.iconSize - 12
                        color: Colors.outline
                    }
                }

                // All Applications opens the Launcher's grid on this screen;
                // Settings toggles the Settings window; Trash opens the
                // trash folder.
                Repeater {
                    model: dock.buttons

                    delegate: Rectangle {
                        id: dockButton
                        required property var modelData
                        readonly property int hoverIndex: dock.items.length + dockButton.modelData.slot

                        width: dock.iconSize
                        height: dock.iconSize
                        radius: Colors.radiusSmall
                        color: buttonMouse.pressed ? Colors.overlay
                            : buttonMouse.containsMouse ? Colors.surfaceHigh : "transparent"
                        transformOrigin: dock.growOrigin
                        scale: dock.magnification(dock.vertical ? dockButton.y + dockButton.height / 2 : dockButton.x + dockButton.width / 2)
                        Accessible.role: Accessible.Button
                        Accessible.name: dockButton.modelData.label
                        Behavior on color { ColorAnimation { duration: Config.animFast } }
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        MaterialIcon {
                            id: buttonIcon
                            readonly property bool trash: dockButton.modelData.slot === 2
                            anchors.centerIn: parent
                            icon: dockButton.modelData.icon
                            // Trash fills when it has something in it.
                            filled: buttonIcon.trash && Dock.trashFull
                            font.pixelSize: Math.round(dock.iconSize * 0.55)
                            color: Colors.text
                            // Native rasterization preserves the Trash glyph's thin
                            // strokes. Supersample its layer for smooth magnification.
                            renderType: buttonIcon.trash ? Text.NativeRendering : Text.QtRendering
                            layer.enabled: buttonIcon.trash
                            layer.smooth: true
                            layer.mipmap: true
                            layer.textureSize: Qt.size(
                                Math.ceil(width * dock.magnifyScale * (dock.modelData.devicePixelRatio || 1)),
                                Math.ceil(height * dock.magnifyScale * (dock.modelData.devicePixelRatio || 1)))
                        }

                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: {
                                if (containsMouse) dock.hoveredIndex = dockButton.hoverIndex;
                                else if (dock.hoveredIndex === dockButton.hoverIndex) dock.hoveredIndex = -1;
                            }
                            onClicked: {
                                dock.menuItem = null;
                                if (dockButton.modelData.slot === 0) Launcher.showApps(dock.modelData.name);
                                else if (dockButton.modelData.slot === 1) Bridge.toggleSettings(dock.modelData.name);
                                else Dock.openTrash();
                            }
                        }
                    }
                }
            }
        }
    }

    // App name beside the hovered icon.
    Rectangle {
        id: tooltip
        readonly property string label: dock.hoveredIndex < 0 ? ""
            : dock.hoveredItem ? dock.hoveredItem.name
            : dock.buttonAt(dock.hoveredIndex) ? dock.buttonAt(dock.hoveredIndex).label : ""
        readonly property point pos: dock.popupPos(width, height, dock.hoveredIndex, dock.magnifyLift)
        visible: Dock.showTooltips && dock.revealed && tooltip.label !== "" && dock.dragIndex < 0 && dock.menuItem === null && dock.previewItem === null
        width: tooltipText.implicitWidth + 20
        height: tooltipText.implicitHeight + 10
        radius: height / 2
        color: Colors.surface
        x: tooltip.pos.x
        y: tooltip.pos.y

        StyledText {
            id: tooltipText
            anchors.centerIn: parent
            text: tooltip.label
            font.pixelSize: Config.fontSize - 1
        }
    }

    DockPreview {
        id: preview
        // Fixed clearance, so previews don't jump as magnification ends.
        readonly property point pos: dock.popupPos(width, height, dock.previewIndex, dock.magnifyRoom)
        visible: dock.previewItem !== null && dock.revealed
        item: dock.previewItem
        maxWidth: dock.vertical ? dock.width - dockArea.width - 24 : dock.width - 16
        width: visible ? implicitWidth : 0
        height: visible ? implicitHeight : 0
        x: preview.pos.x
        y: preview.pos.y
    }

    MenuList {
        id: menu
        readonly property point pos: dock.popupPos(width, height, dock.menuIndex, 0)
        visible: dock.menuItem !== null
        entries: dock.menuEntries(dock.menuItem)
        // Room between the Dock and the far edge of the window; longer
        // menus scroll.
        maxHeight: dock.vertical ? dock.height - 16 : dockArea.y + body.y - 16
        width: implicitWidth
        height: visible ? implicitHeight : 0
        x: menu.pos.x
        y: menu.pos.y
        onTriggered: dock.menuItem = null
        onDismissed: dock.menuItem = null
    }
}
