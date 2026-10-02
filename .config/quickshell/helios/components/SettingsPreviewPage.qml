import QtQuick
import "../services"

// Settings pages with a live preview that stays above their scrolling controls.
Item {
    id: root
    property string title: ""
    property string icon: ""
    property Component previewComponent
    default property alias content: contentSlot.data

    implicitWidth: 320
    implicitHeight: previewFrame.y + previewFrame.height + 16 + controls.contentHeight

    Row {
        id: heading
        spacing: 8
        MaterialIcon { icon: root.icon; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: root.title; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
    }

    Item {
        id: previewFrame
        objectName: "settingsPreviewFrame"
        anchors.top: heading.bottom
        anchors.topMargin: 10
        width: parent.width
        height: Math.min(180, preview.implicitHeight)

        Loader {
            id: preview
            objectName: "settingsPreviewLoader"
            width: parent.width
            anchors.centerIn: parent
            sourceComponent: root.previewComponent
            scale: implicitHeight > 0 ? Math.min(1, previewFrame.height / implicitHeight) : 1
            layer.enabled: scale < 1
            layer.smooth: true
            layer.mipmap: true
        }
    }

    Flickable {
        id: controls
        objectName: "settingsControlsFlick"
        anchors.top: previewFrame.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        width: parent.width
        contentWidth: width
        contentHeight: contentSlot.childrenRect.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Item {
            id: contentSlot
            width: controls.width
            height: childrenRect.height
        }
    }
    ScrollIndicator { target: controls }
}
