import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../../services"
import "../../components"
import "../island"

// Settings > Island — static preview of the idle pill and the hover row,
// built from the real IslandIdle/IslandPeek so every setting shows as it
// changes. Input is off; the hover row shrinks to fit the card. The idle
// pill sits on the top of the wallpaper, placed by the current layout.
Rectangle {
    id: root

    readonly property var targetScreen: {
        const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        return Quickshell.screens.find(s => s.name === focused) || Quickshell.screens[0] || null;
    }
    readonly property bool mediaPlaying: (Mpris.players ? Mpris.players.values : []).some(p => p.isPlaying)

    width: parent ? parent.width : 0
    implicitHeight: stage.implicitHeight + 36
    height: implicitHeight
    radius: Colors.radiusLarge
    color: Colors.surfaceHigh
    enabled: false

    Column {
        id: stage
        x: 18
        y: 18
        width: root.width - 36
        spacing: 14

        // The top of the screen: Island and Quiet float below the top gap,
        // Notch hangs from the edge, Zen is hidden until pointed at (faded).
        Rectangle {
            objectName: "islandPreviewScreen"
            width: parent.width
            height: idleShape.y + idleShape.height + 16
            color: Colors.surfaceContainer
            clip: true

            Image {
                anchors.fill: parent
                source: Wallpaper.isVideo ? "" : Wallpaper.source
                sourceSize.width: Math.ceil(width * 2)
                fillMode: Image.PreserveAspectCrop
                verticalAlignment: Image.AlignTop
                asynchronous: true
            }

            IslandShape {
                id: idleShape
                objectName: "islandPreviewShape"
                anchors.horizontalCenter: parent.horizontalCenter
                y: Config.islandTopGap
                width: idle.implicitWidth
                height: idle.implicitHeight
                attached: Config.islandAttached
                fillColor: Colors.background
                opacity: Config.islandAutoHide ? 0.35 : 1

                IslandIdle {
                    id: idle
                    objectName: "islandPreviewIdle"
                    anchors.fill: parent
                    targetScreen: root.targetScreen
                    mediaPlaying: root.mediaPlaying
                }
            }
        }

        // Scaling text directly rasterizes it at full size and shrinks it
        // unfiltered (jagged). When the row needs shrinking, render it into
        // a mipmapped layer first, padded so the shadow isn't clipped.
        Item {
            id: peekFrame
            readonly property int pad: 24
            readonly property real naturalWidth: peek.implicitWidth + Config.islandContentPadH * 2
            readonly property real naturalHeight: peek.implicitHeight + Config.islandContentPadV * 2
            readonly property real fit: Math.min(1, stage.width / Math.max(1, naturalWidth))
            anchors.horizontalCenter: parent.horizontalCenter
            width: naturalWidth * fit
            height: naturalHeight * fit

            Item {
                x: -peekFrame.pad * peekFrame.fit
                y: -peekFrame.pad * peekFrame.fit
                width: peekFrame.naturalWidth + peekFrame.pad * 2
                height: peekFrame.naturalHeight + peekFrame.pad * 2
                scale: peekFrame.fit
                transformOrigin: Item.TopLeft
                layer.enabled: peekFrame.fit < 1
                layer.smooth: true
                layer.mipmap: true

                IslandShape {
                    expanded: true
                    x: peekFrame.pad
                    y: peekFrame.pad
                    width: peekFrame.naturalWidth
                    height: peekFrame.naturalHeight

                    IslandPeek {
                        id: peek
                        x: Config.islandContentPadH
                        y: Config.islandContentPadV
                        targetScreen: root.targetScreen
                    }
                }
            }
        }
    }
}
