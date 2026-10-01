import QtQuick
import "../../../services"
import "../../../services/Utils.js" as Utils
import "../../../components"

// "↓ 4.6 M/s  ↑ 2.2 M/s" — the accent arrow is the primary (read /
// download) series, the muted one the secondary, matching LineGraph's colors.
Row {
    id: root

    property real downBytesPerSec: 0
    property real upBytesPerSec: 0

    spacing: 3

    MaterialIcon { icon: "arrow_downward"; font.pixelSize: 13; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
    StyledText { text: Utils.formatBytesPerSec(root.downBytesPerSec); font.pixelSize: Config.fontSize - 2; font.family: Config.monoFontFamily; anchors.verticalCenter: parent.verticalCenter }
    Item { width: 10; height: 1 }
    MaterialIcon { icon: "arrow_upward"; font.pixelSize: 13; color: Colors.subtext; anchors.verticalCenter: parent.verticalCenter }
    StyledText { text: Utils.formatBytesPerSec(root.upBytesPerSec); font.pixelSize: Config.fontSize - 2; font.family: Config.monoFontFamily; anchors.verticalCenter: parent.verticalCenter }
}
