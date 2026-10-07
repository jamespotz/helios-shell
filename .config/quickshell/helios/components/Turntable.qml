import QtQuick
import Quickshell.Widgets
import "../services"

// Shared record player designs. Playback drives record and tonearm motion.
Item {
    id: root

    property string artUrl: ""
    property bool playing: false
    property real progress: 0
    // Record diameter before the shared size preference is applied.
    property real size: 160

    readonly property real rpm: Config.turntableSpeed === "45" ? 45 : 100 / 3
    readonly property real _recordDiameter: root.size * Config.turntableScale / 100
    readonly property real _baseSize: root._recordDiameter / 0.84
    readonly property bool _studio: Config.turntableDesign === "studio"
    readonly property bool _sleeve: Config.turntableDesign === "sleeve"
    readonly property bool _hasDeck: Config.turntableDesign === "classic" || root._studio
    readonly property color _vinyl: "#101211"
    readonly property var _platterPreset: Config.turntablePlatterPresets.find(preset => preset.value === Config.turntablePlatter)
        || Config.turntablePlatterPresets[0]
    readonly property color _groove: Config.turntablePlatter === "black" ? "#1b1d1c" : Qt.rgba(0, 0, 0, 0.18)
    readonly property color _metal: "#b7b7b4"
    readonly property color _baseColor: Config.turntableFinish === "theme" ? Colors.surfaceHigh
        : Config.turntableFinish === "charcoal" ? "#353637" : "#e9e6df"

    implicitWidth: root._baseSize * (root._sleeve ? 1.5 : root._studio ? 1.32 : 1)
    implicitHeight: root._baseSize

    // Coast on pause, but stop immediately for explicit animation controls.
    property real _speed: root.playing && Config.turntableSpin && !Config.reducedMotion ? 1 : 0
    Behavior on _speed {
        enabled: Config.turntableSpin && !Config.reducedMotion
        NumberAnimation {
            duration: root.playing ? 900 : 1800
            easing.type: root.playing ? Easing.InOutSine : Easing.OutCubic
        }
    }
    FrameAnimation {
        objectName: "turntableMotion"
        running: root.visible && Config.turntableSpin && !Config.reducedMotion && root._speed > 0.001
        onTriggered: record.rotation = (record.rotation + frameTime * root.rpm * 6 * root._speed) % 360
    }

    Rectangle {
        objectName: "turntableBase"
        visible: root._hasDeck
        anchors.fill: parent
        radius: Math.min(Colors.radiusLarge, width * 0.065)
        color: root._baseColor
        antialiasing: true
    }

    // Decorative hardware only, without input handlers or focus targets.
    Item {
        objectName: "turntableDeckButtons"
        anchors.fill: parent
        visible: root._hasDeck
        Accessible.ignored: true

        Rectangle {
            objectName: "turntableDeckPower"
            x: root._baseSize * 0.06
            y: root.height - root._baseSize * 0.075
            width: root._baseSize * 0.045
            height: width
            radius: width / 2
            color: root._vinyl
            antialiasing: true

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.25
                height: width
                radius: width / 2
                color: root._metal
                antialiasing: true
            }
        }
        Row {
            x: root.width - width - root._baseSize * 0.06
            y: root.height - root._baseSize * 0.055
            spacing: root._baseSize * 0.02

            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    objectName: "turntableDeckKey_" + index
                    width: root._baseSize * 0.075
                    height: root._baseSize * 0.028
                    radius: root._baseSize * 0.005
                    color: root._metal
                    border.width: Math.max(0.5, root._baseSize * 0.003)
                    border.color: Qt.alpha(root._vinyl, 0.35)
                    antialiasing: true
                }
            }
        }
    }

    SurfaceShadow {
        anchors.fill: record
        cornerRadius: record.radius
        glowRadius: root._recordDiameter * 0.04
        spread: 0
        verticalOffset: root._recordDiameter * 0.025
        shadowOpacity: 0.2
    }

    Rectangle {
        id: record
        objectName: "turntableRecord"
        x: root._sleeve ? root._baseSize * 0.52 : root._studio ? root._baseSize * 0.06 : (root.width - width) / 2
        y: (root.height - height) / 2
        width: root._recordDiameter
        height: width
        radius: width / 2
        color: root._platterPreset.color
        gradient: root._platterPreset.endColor ? platterGradient : null
        border.width: Math.max(1, width * 0.005)
        border.color: root._groove
        antialiasing: true

        Gradient {
            id: platterGradient
            GradientStop { position: 0; color: root._platterPreset.color }
            GradientStop { position: 1; color: root._platterPreset.endColor || root._platterPreset.color }
        }

        Repeater {
            model: root._sleeve ? 8 : 4
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: record.width * (0.96 - index * 0.048)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(0.5, record.width * 0.004)
                border.color: root._groove
                antialiasing: true
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: artwork.width + root._recordDiameter * 0.025
            height: width
            radius: width / 2
            color: "#090a09"
        }
        ClippingRectangle {
            id: artwork
            objectName: "turntableArtwork"
            anchors.centerIn: parent
            width: record.width * Config.turntableArtworkSize / 100
            height: width
            radius: width / 2
            color: root._sleeve ? root._baseColor : Colors.accent

            MaterialIcon {
                anchors.centerIn: parent
                visible: root._sleeve || art.status !== Image.Ready
                icon: "music_note"
                font.pixelSize: parent.width * 0.35
                color: !root._sleeve ? Colors.accentText
                    : Config.turntableFinish === "cream" ? root._vinyl
                    : Config.turntableFinish === "charcoal" ? root._metal : Colors.text
            }
            Image {
                id: art
                anchors.fill: parent
                source: root._sleeve ? "" : root.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width * 2, height * 2)
                asynchronous: true
                smooth: true
                mipmap: true
            }
        }
    }

    SurfaceShadow {
        visible: root._sleeve
        anchors.fill: sleeveArtwork
        cornerRadius: sleeveArtwork.radius
        glowRadius: root._recordDiameter * 0.035
        spread: 0
        verticalOffset: root._recordDiameter * 0.015
        shadowOpacity: 0.18
    }
    ClippingRectangle {
        id: sleeveArtwork
        objectName: "turntableSleeveArtwork"
        visible: root._sleeve
        x: root._baseSize * 0.02
        y: (root.height - height) / 2
        width: root._baseSize * 0.94
        height: width
        radius: Math.min(Colors.radiusSmall, width * 0.018)
        color: Colors.accent

        MaterialIcon {
            anchors.centerIn: parent
            visible: sleeveImage.status !== Image.Ready
            icon: "music_note"
            font.pixelSize: parent.width * 0.35
            color: Colors.accentText
        }
        Image {
            id: sleeveImage
            objectName: "turntableSleeveImage"
            anchors.fill: parent
            source: root._sleeve ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }

    Rectangle {
        objectName: "turntablePivot"
        visible: Config.turntableTonearm
        x: tonearm.x - width / 2
        y: tonearm.y - height / 2
        width: root._baseSize * 0.19
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, root._baseSize * 0.005)
        border.color: Qt.rgba(root._metal.r, root._metal.g, root._metal.b, 0.45)
        antialiasing: true
    }

    Item {
        id: tonearm
        objectName: "turntableTonearm"
        visible: Config.turntableTonearm
        x: root._baseSize * (root._sleeve ? 1.36 : root._studio ? 1.1 : 0.855)
        y: root._baseSize * (root._sleeve ? 0.17 : root._studio ? 0.155 : 0.165)
        readonly property real armLength: root._baseSize * (root._sleeve ? 0.67 : root._studio ? 0.72 : 0.59)
        rotation: root.playing ? (root._sleeve ? 18 : root._studio ? 30 : 6)
            + (Config.turntableTrackProgress ? Math.max(0, Math.min(1, root.progress)) * 10 : 0)
            : root._sleeve ? -4 : root._studio ? -7 : 0
        Behavior on rotation {
            enabled: !Config.reducedMotion && root.visible && Config.turntableTonearm
            Spring {}
        }

        // Counterweight and pivot housing.
        Rectangle {
            x: -width / 2
            y: -height * 0.65
            width: root._baseSize * 0.055
            height: root._baseSize * 0.075
            radius: width * 0.08
            color: root._vinyl
            rotation: -5
            antialiasing: true
        }
        Rectangle {
            x: -width / 2
            y: 0
            width: Math.max(1.5, root._baseSize * 0.012)
            height: tonearm.armLength
            radius: width / 2
            color: root._metal
            antialiasing: true
        }
        Rectangle {
            x: -width / 2
            y: tonearm.armLength - height * 0.4
            width: root._baseSize * 0.04
            height: root._baseSize * 0.09
            radius: width * 0.12
            color: root._vinyl
            rotation: 7
            antialiasing: true
        }
    }
}
