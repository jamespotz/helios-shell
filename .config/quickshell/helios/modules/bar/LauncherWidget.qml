import QtQuick
import "../../services"
import "../../components"

IconButton {
    id: root
    property var targetScreen: null
    label: qsTr("Open Launcher")
    onClicked: if (root.targetScreen) Launcher.showApps(root.targetScreen.name)
    Image {
        id: logo
        anchors.centerIn: parent
        width: root.iconSize
        height: width
        source: LauncherIcon.source
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        visible: status === Image.Ready
    }
    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: width
        source: Qt.resolvedUrl("../../data/linux.svg")
        fillMode: Image.PreserveAspectFit
        visible: logo.status !== Image.Ready
    }
}
