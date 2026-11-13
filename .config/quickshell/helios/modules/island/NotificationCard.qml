import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Notification alert card. One notification shows in full. Several stack:
// the newest in front, up to two older ones peeking out below it, scaled
// back. Hovering fans the stack out into a list; dragging a card sideways
// dismisses it.
Item {
    id: root

    readonly property var list: Notifications.state.popups
    readonly property int count: list.length

    readonly property bool hovering: hoverTracker.hovered
    readonly property bool expanded: root.hovering && root.count > 1
    // Cards past this stay hidden until the ones in front go.
    readonly property int visibleMax: 3
    readonly property int visibleCount: Math.min(root.count, root.visibleMax)
    // How far each card behind shows below the front one, and the space
    // between cards once fanned out.
    readonly property int peek: 8
    readonly property int gap: 8
    // Drag past this, or flick faster than swipeVelocity (px/s), to dismiss.
    readonly property int swipeThreshold: 45
    readonly property int swipeVelocity: 400

    function iconSource(notification) {
        return notification.image || Quickshell.iconPath(notification.appIcon, true);
    }

    // Each card's natural height by id, reported by the cards themselves;
    // the stack and the fanned-out list are laid out from these.
    property var heights: ({})
    function setHeight(id, h) {
        if (root.heights[id] === h) return;
        const next = {};
        for (const n of root.list) if (root.heights[n.id] !== undefined) next[n.id] = root.heights[n.id];
        next[id] = h;
        root.heights = next;
    }
    function heightOf(index) {
        const n = root.list[index];
        return n && root.heights[n.id] !== undefined ? root.heights[n.id] : 0;
    }
    function expandedY(index) {
        let y = 0;
        for (let i = 0; i < index; i++) y += root.heightOf(i) + root.gap;
        return y;
    }
    readonly property real frontHeight: root.heightOf(0)

    implicitWidth: Config.notifyWidth
    implicitHeight: root.expanded
        ? root.expandedY(root.visibleCount) + footer.height
        : root.frontHeight + root.peek * Math.max(0, root.visibleCount - 1)

    HoverHandler { id: hoverTracker }

    // Auto-dismiss notifications after a pause. Each new notification
    // restarts the timer, and hovering keeps the current card or stack open.
    // Urgency sets the pause and which cards go (see NotificationCore.expiry):
    // low-only stacks leave sooner, critical ones can wait for a dismiss.
    // This timer only exists while notifications are actually on screen, so
    // nothing ticks down while an open panel covers them.
    readonly property var expiry: Notifications.expiry(root.list, Config.notifyDuration, Config.keepCriticalAlerts)

    function _rearm() {
        if (root.expiry.interval > 0) autoDismissTimer.restart();
        else autoDismissTimer.stop();
    }

    Timer {
        id: autoDismissTimer
        interval: Math.max(1, root.expiry.interval)
        onTriggered: {
            if (root.hovering) { autoDismissTimer.restart(); return; }
            for (const id of root.expiry.dismissIds) Notifications.dismiss(id);
        }
    }

    onExpiryChanged: root._rearm()
    Component.onCompleted: root._rearm()

    Repeater {
        model: ScriptModel { values: root.list }

        delegate: Item {
            id: toast
            required property var modelData
            required property int index

            readonly property bool front: index === 0
            readonly property bool shown: index < root.visibleMax
            readonly property int depth: Math.min(index, root.visibleMax - 1)
            readonly property bool stacked: root.count > 1
            // Cards behind the front take its height and hide their content,
            // so only their lower edge shows.
            readonly property bool open: toast.front || root.expanded
            readonly property int pad: toast.stacked ? 10 : 0
            readonly property real naturalHeight: content.implicitHeight + toast.pad * 2
            onNaturalHeightChanged: root.setHeight(toast.modelData.id, toast.naturalHeight)

            // Arrival: slides down into place from just above.
            property real enter: 0
            Component.onCompleted: {
                root.setHeight(toast.modelData.id, toast.naturalHeight);
                toast.enter = 1;
            }
            Behavior on enter { enabled: !Config.reducedMotion; Spring {} }

            // Horizontal drag offset; past the threshold the card keeps going
            // and is dismissed once fully out.
            property real swipeX: 0
            property bool dismissing: false
            Behavior on swipeX { enabled: !Config.reducedMotion && !swipe.active; Spring {} }
            onSwipeXChanged: if (toast.dismissing && Math.abs(toast.swipeX) >= root.width) Notifications.dismiss(toast.modelData.id)

            readonly property real stackScale: toast.open ? 1 : 1 - 0.05 * toast.depth
            readonly property real stackHeight: toast.open ? toast.naturalHeight : root.frontHeight
            // Scaled from the top, so place it for its lower edge to sit
            // `peek` px per card below the front card's.
            property real stackY: root.expanded ? root.expandedY(toast.index)
                : root.frontHeight + root.peek * toast.depth - toast.stackHeight * toast.stackScale

            width: root.width
            height: toast.stackHeight
            x: toast.swipeX
            y: toast.stackY - (1 - toast.enter) * 16
            z: -toast.index
            scale: toast.stackScale
            transformOrigin: Item.Top
            opacity: (toast.shown ? 1 : 0) * toast.enter * (1 - Math.min(1, Math.abs(toast.swipeX) / root.width))

            Behavior on height { enabled: !Config.reducedMotion; Spring {} }
            Behavior on stackY { enabled: !Config.reducedMotion; Spring {} }
            Behavior on scale { enabled: !Config.reducedMotion; Spring {} }

            DragHandler {
                id: swipe
                target: null
                enabled: toast.open && toast.shown && !toast.dismissing
                yAxis.enabled: false
                onActiveTranslationChanged: if (active) toast.swipeX = activeTranslation.x
                onActiveChanged: {
                    if (active) return;
                    const flicked = Math.abs(centroid.velocity.x) > root.swipeVelocity;
                    if (Math.abs(toast.swipeX) > root.swipeThreshold || flicked) {
                        const dir = (flicked ? centroid.velocity.x : toast.swipeX) < 0 ? -1 : 1;
                        toast.dismissing = true;
                        AlertSounds.play("tap");
                        toast.swipeX = dir * (root.width + 24);
                    } else {
                        toast.swipeX = 0;
                    }
                }
            }

            // A plate per card once there's a stack to tell them apart. Cards
            // behind dim with depth so their edges read as layers.
            Rectangle {
                anchors.fill: parent
                visible: toast.stacked
                radius: Colors.radiusSmall
                color: Colors.surfaceHigh
                opacity: toast.open ? 1 : 1 - 0.3 * toast.depth
                Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
            }

            Row {
                id: content
                x: toast.pad
                y: toast.pad
                width: parent.width - toast.pad * 2
                spacing: 12
                opacity: toast.open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

                // App icon — rounded square (Apple notification style)
                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: toast.stacked ? Colors.surface : Colors.surfaceHigh
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: source !== ""
                        source: root.iconSource(toast.modelData)
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Column {
                    width: parent.width - 36 - 12 - actionRow.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        font.pixelSize: Config.fontSize
                        text: toast.modelData.summary
                    }
                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        color: Colors.subtext
                        font.pixelSize: Config.fontSize - 1
                        text: toast.modelData.body
                    }
                }

                Row {
                    id: actionRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    IconButton {
                        icon: "open_in_new"
                        iconSize: 14
                        visible: toast.modelData.canOpen
                        onClicked: Notifications.open(toast.modelData.id)
                    }

                    IconButton {
                        icon: "close"
                        iconSize: 14
                        onClicked: Notifications.dismiss(toast.modelData.id)
                    }
                }
            }
        }
    }

    // Under the fanned-out list: how many there are, and Clear all.
    Item {
        id: footer
        y: root.expandedY(root.visibleCount)
        width: parent.width
        height: 28
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.subtext
            font.pixelSize: Config.fontSize - 1
            text: root.count > root.visibleMax
                ? qsTr("%1 notifications, %2 more after these").arg(root.count).arg(root.count - root.visibleMax)
                : qsTr("%1 notifications").arg(root.count)
        }

        Chip {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Clear all")
            inactiveTint: Colors.surfaceHigh
            onClicked: Notifications.dismissAll()
        }
    }
}
