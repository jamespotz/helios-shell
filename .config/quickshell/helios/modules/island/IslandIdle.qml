import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../services"
import "../../components"

// The collapsed idle pill — Apple Dynamic Island style: minimal, clean,
// with generous internal spacing and refined typography. Which widgets
// show, their order, and their side come from Config (Settings > Island).
Item {
    id: root

    property bool mediaPlaying: false
    property var targetScreen: null

    readonly property var player: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.find(p => p.isPlaying) || null;
    }

    readonly property var layout: Config.idleWidgetLayout
    readonly property var leftKeys: root.layout.slice(0, root.layout.indexOf("|"))
    readonly property var rightKeys: root.layout.slice(root.layout.indexOf("|") + 1)

    function shows(key) {
        if (!Config.widgetShown("idle", key)) return false;
        if (key === "media") return root.mediaPlaying;
        if (key === "weather") return Weather.available;
        return true;
    }

    readonly property bool hasLeft: root.leftKeys.some(k => root.shows(k))
    readonly property bool hasRight: root.rightKeys.some(k => root.shows(k))
    readonly property bool split: root.hasLeft && root.hasRight

    // Content-driven width with a comfortable floor — Apple's idle pill
    // never looks cramped; generous horizontal padding (28px total). With
    // widgets on both sides, each group hugs its edge and the gap sits in
    // the middle; one side alone stays centered.
    implicitWidth: Math.max(Config.idleBumpWidth, root.split
        ? leftRow.implicitWidth + rightRow.implicitWidth + Config.idleWidgetSpacing * 2 + 28
        : leftRow.implicitWidth + rightRow.implicitWidth + 28)
    implicitHeight: Config.idleBumpHeight

    readonly property var widgets: ({
        workspaces: workspacesWidget, tiledLayout: tiledLayoutWidget, activeWindow: activeWindowWidget,
        media: mediaWidget, clock: clockWidget, weather: weatherWidget, tray: trayWidget,
        clipboard: clipboardWidget, statusIndicators: statusWidget, launcher: launcherWidget
    })

    // Inline components can't reach this file's ids, so the pill is passed in.
    component Side: Row {
        id: side
        property var keys: []
        property var pill
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.idleWidgetSpacing

        Repeater {
            model: side.keys

            Loader {
                required property string modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                active: Config.widgetShown("idle", modelData)
                // hasContent: widgets that hide themselves (tiled layout).
                visible: side.pill.shows(modelData) && (!item || item.hasContent !== false)
                sourceComponent: side.pill.widgets[modelData]
            }
        }
    }

    Side {
        id: leftRow
        keys: root.leftKeys
        pill: root
        x: root.split ? 14 : (root.width - implicitWidth) / 2
    }

    Side {
        id: rightRow
        keys: root.rightKeys
        pill: root
        x: root.split ? root.width - 14 - implicitWidth : (root.width - implicitWidth) / 2
    }

    Component {
        id: workspacesWidget
        WorkspacesWidget { targetScreen: root.targetScreen }
    }
    Component { id: launcherWidget; LauncherWidget { targetScreen: root.targetScreen; height: Math.min(30, Config.idleBumpHeight) } }

    Component {
        id: tiledLayoutWidget
        TiledLayoutWidget { active: true; targetScreen: root.targetScreen }
    }

    Component {
        id: activeWindowWidget
        ActiveWindowWidget { width: Math.min(implicitWidth, 120) }
    }

    // Now-playing: album art thumbnail in a circle plus a compact
    // visualizer. Uses ClippingRectangle (the same rounded-image primitive
    // the wallpaper preview uses) rather than a hidden Image + MultiEffect
    // mask, which rendered nothing.
    Component {
        id: mediaWidget
        Row {
            spacing: Config.idleWidgetSpacing

            ClippingRectangle {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: Colors.surfaceHigh
                clip: true

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !(root.player && root.player.trackArtUrl)
                    icon: "music_note"
                    font.pixelSize: 11
                    color: Colors.subtext
                }

                Image {
                    anchors.fill: parent
                    visible: !!(root.player && root.player.trackArtUrl)
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            MiniVisualizer {
                active: root.mediaPlaying
                levels: active ? Cava.downsample(Cava.bars, 5).map(v => v / Cava.maxRange) : []
                barColor: Colors.accent
                maxHeight: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Component {
        id: clockWidget
        FlipClock { weight: Font.Medium; opacity: 0.95 }
    }

    Component {
        id: weatherWidget
        Row {
            spacing: Config.idleWidgetSpacing

            MaterialIcon {
                icon: Weather.icon
                color: Colors.accent
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Config.fontSize - 1
                font.weight: Font.Medium
                text: Weather.formatTemperature(Weather.tempC)
                opacity: 0.85
            }
        }
    }

    Component {
        id: trayWidget
        TrayWidget {}
    }

    Component {
        id: clipboardWidget
        ClipboardWidget { targetScreen: root.targetScreen }
    }

    Component {
        id: statusWidget
        StatusWidget { targetScreen: root.targetScreen }
    }

}
