import QtQuick
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

// Small glanceable rx/tx rate readout next to the network icon. Display
// only — bandwidth has no toggle or setting, so no click target.
Row {
    id: root
    spacing: 4
    visible: NetInfo.rxRate > 0 || NetInfo.txRate > 0

    MaterialIcon { icon: "arrow_downward"; font.pixelSize: 11; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
    StyledText {
        text: Utils.formatBytesPerSec(NetInfo.rxRate)
        font.pixelSize: Config.fontSize - 3
        opacity: 0.6
        anchors.verticalCenter: parent.verticalCenter
    }
    MaterialIcon { icon: "arrow_upward"; font.pixelSize: 11; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
    StyledText {
        text: Utils.formatBytesPerSec(NetInfo.txRate)
        font.pixelSize: Config.fontSize - 3
        opacity: 0.6
        anchors.verticalCenter: parent.verticalCenter
    }
}
