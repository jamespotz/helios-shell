import QtQuick
import "../services"

// Focused "single connection" orbit visualization — a center circle showing
// the active connection ringed by satellite cards that drift around it.
// Shared by BluetoothTab and WifiTab's orbit views, which used to
// reimplement this (animation, trig, layout) independently. Presentation
// only: callers pass already-resolved display strings and handle the scan/
// switch-view actions themselves via signals.
Item {
    id: root

    property bool active: false  // drives the orbit rotation; pause when hidden

    property string centerIcon
    property string centerTitle
    property string centerSubtitle

    property string scanIcon: "search"
    property string scanLabel
    property string scanSubLabel: "Switch View"

    // Three satellite info cards at 180°, 0°, and 90° (the scan card owns
    // -90°): [{ angle, width, icon, value, label, monospace }, ...]
    required property var infoCards

    signal scanClicked()
    signal switchViewClicked()

    width: parent.width
    height: 460

    Item {
        id: orbitCenter
        anchors.centerIn: parent
        width: 1
        height: 1

        // Drives the satellite cards around the outer ring — cards travel
        // the circle but stay upright (position-only, no rotation on the
        // cards themselves) so their text stays readable throughout.
        // Paused when the panel isn't visible.
        property real orbitAngle: 0
        NumberAnimation on orbitAngle {
            running: root.active
            from: 0
            to: 360
            duration: 60000
            loops: Animation.Infinite
        }

        // Drives the sway of every rope tether — one shared phase so all
        // ropes stay in lockstep timing-wise while each offsets it
        // differently (see OrbitRope.phaseOffset) for an organic look.
        property real wavePhase: 0
        NumberAnimation on wavePhase {
            running: root.active
            from: 0
            to: Math.PI * 2
            duration: 4000
            loops: Animation.Infinite
        }

        OrbitRope {
            anchors.centerIn: parent
            width: 400
            height: 400
            targetX: 190 * Math.cos((orbitCenter.orbitAngle - 90) * Math.PI / 180)
            targetY: 190 * Math.sin((orbitCenter.orbitAngle - 90) * Math.PI / 180)
            wavePhase: orbitCenter.wavePhase
            phaseOffset: -90 * Math.PI / 180
        }

        Repeater {
            model: root.infoCards
            OrbitRope {
                required property var modelData
                anchors.centerIn: parent
                width: 400
                height: 400
                targetX: 190 * Math.cos((orbitCenter.orbitAngle + modelData.angle) * Math.PI / 180)
                targetY: 190 * Math.sin((orbitCenter.orbitAngle + modelData.angle) * Math.PI / 180)
                wavePhase: orbitCenter.wavePhase
                phaseOffset: modelData.angle * Math.PI / 180
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 150
            height: 150
            radius: 75
            color: Colors.secondary

            Column {
                anchors.centerIn: parent
                spacing: 4
                MaterialIcon {
                    icon: root.centerIcon
                    font.pixelSize: 40
                    color: Colors.secondaryText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    text: root.centerTitle
                    color: Colors.secondaryText
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    text: root.centerSubtitle
                    color: Colors.secondaryText
                    opacity: 0.75
                    font.pixelSize: Config.fontSize - 2
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // --- Scan / switch-view satellite -----------------------------------
        Rectangle {
            id: scanCard
            width: 190
            height: 56
            radius: Colors.radiusLarge
            color: Colors.surfaceHigh
            readonly property real orbitBaseAngle: -90
            x: 190 * Math.cos((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - width / 2
            y: 190 * Math.sin((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - height / 2

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                MaterialIcon { icon: root.scanIcon; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    spacing: 2
                    StyledText { text: root.scanLabel; font.bold: true; font.pixelSize: Config.fontSize - 1 }
                    StyledText { text: root.scanSubLabel; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Colors.surfaceHigh
                opacity: scanCardHover.hovered ? 0.15 : 0
            }

            HoverHandler { id: scanCardHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.scanClicked()
            }
            MouseArea {
                // "Switch View" label only
                height: 18
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: 90
                cursorShape: Qt.PointingHandCursor
                onClicked: root.switchViewClicked()
            }
        }

        // --- Info satellites -------------------------------------------------
        Repeater {
            model: root.infoCards

            Rectangle {
                required property var modelData

                width: modelData.width
                height: 56
                radius: Colors.radiusLarge
                color: Colors.surfaceHigh
                x: 190 * Math.cos((orbitCenter.orbitAngle + modelData.angle) * Math.PI / 180) - width / 2
                y: 190 * Math.sin((orbitCenter.orbitAngle + modelData.angle) * Math.PI / 180) - height / 2

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    MaterialIcon { icon: modelData.icon; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 2
                        StyledText {
                            text: modelData.value
                            font.bold: true
                            font.family: modelData.monospace ? Config.monoFontFamily : Config.fontFamily
                            font.pixelSize: modelData.monospace ? Config.fontSize - 2 : Config.fontSize - 1
                        }
                        StyledText { text: modelData.label; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                    }
                }
            }
        }
    }
}
