import QtQuick
import Quickshell.Services.UPower
import "../../services"
import "../../components"

// Power profile switcher: a 3-way segmented pill (Power Saver / Balanced /
// Performance) backed by power-profiles-daemon via Quickshell's UPower
// service. Mirrors the Wi-Fi/Bluetooth pill switcher in BluetoothTab.qml,
// but with a single sliding highlight behind all three segments rather than
// each segment owning its own fill — reads closer to iOS/macOS toggles.
Item {
    id: root

    readonly property var segments: [
        { profile: PowerProfile.PowerSaver, icon: "eco", label: "Saver", color: Colors.success,
          blurb: "Maximizes battery life by capping performance." },
        { profile: PowerProfile.Balanced, icon: "balance", label: "Balanced", color: Colors.accent,
          blurb: "Balances performance and battery life." },
        { profile: PowerProfile.Performance, icon: "bolt", label: "Performance", color: Colors.danger,
          blurb: "Maximizes performance. Uses more power and battery." }
    ]

    readonly property int activeIndex: {
        for (let i = 0; i < root.segments.length; i++)
            if (root.segments[i].profile === PowerProfiles.profile) return i;
        return 1;
    }
    readonly property var activeSegment: root.segments[root.activeIndex]

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        Item {
            width: parent.width
            height: 24

            MaterialIcon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: root.activeSegment.icon
                color: root.activeSegment.color
            }
            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                text: "Power Mode"
            }
        }

        // --- Segmented pill -------------------------------------------------
        Rectangle {
            id: pill
            width: parent.width
            height: 44
            radius: 22
            color: Colors.surfaceHigh

            readonly property real segmentWidth: (width - 6) / root.segments.length

            Rectangle {
                id: highlight
                width: pill.segmentWidth
                height: pill.height - 6
                radius: height / 2
                y: 3
                x: 3 + pill.segmentWidth * root.activeIndex
                color: root.activeSegment.color

                Behavior on x {
                    SpringAnimation { spring: Config.islandSpringStiffness; damping: Config.islandSpringDamping }
                }
                Behavior on color { ColorAnimation { duration: Config.animFast } }
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: root.segments

                    Item {
                        id: seg
                        required property var modelData
                        required property int index

                        readonly property bool isActive: index === root.activeIndex
                        readonly property bool isEnabled: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                        width: pill.segmentWidth
                        height: pill.height
                        opacity: isEnabled ? 1 : 0.35

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: height / 2
                            color: Colors.surface
                            opacity: !seg.isActive && segHover.hovered && seg.isEnabled ? 0.25 : 0
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                icon: seg.modelData.icon
                                font.pixelSize: 15
                                color: seg.isActive ? Colors.accentText : Colors.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: seg.modelData.label
                                color: seg.isActive ? Colors.accentText : Colors.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: segHover; enabled: seg.isEnabled }

                        MouseArea {
                            anchors.fill: parent
                            enabled: seg.isEnabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfiles.profile = seg.modelData.profile
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: PowerProfiles.hasPerformanceProfile ? root.activeSegment.blurb
                : "Performance mode unavailable on this device."
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // --- Active holds: apps pinning a profile away from the user's choice ---
        Column {
            width: parent.width
            spacing: 6
            visible: PowerProfiles.holds.length > 0

            StyledText {
                text: "Held by"
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
            }

            Repeater {
                model: PowerProfiles.holds

                Row {
                    required property var modelData
                    spacing: 8

                    MaterialIcon {
                        icon: "lock"
                        font.pixelSize: 14
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: modelData.applicationId + (modelData.reason ? " — " + modelData.reason : "")
                        opacity: 0.7
                        font.pixelSize: Config.fontSize - 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
