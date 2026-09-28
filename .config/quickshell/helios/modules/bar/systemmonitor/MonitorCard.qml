import QtQuick
import "../../../services"
import "../../../components"

// Card shell for the System monitor grid: a big value + unit (or a plain
// title), a label, a quiet icon top-right, the card body, and an optional
// footer with leading text and one action. The footer pins to the bottom so
// cards stretched to a row's height keep their actions aligned.
Rectangle {
    id: root

    property string title: ""
    property string value: ""
    property string unit: ""
    property string label: ""
    property string icon: ""
    property color iconColor: Colors.text
    property string footerText: ""
    property string actionText: ""
    property bool actionVisible: root.actionText.length > 0
    property bool actionEnabled: true
    default property alias content: body.data

    signal actionTriggered()

    function levelColor(pct, warnAt, hotAt) {
        return pct >= hotAt ? Colors.danger : pct >= warnAt ? Colors.warning : Colors.accent;
    }

    readonly property int padding: 14
    readonly property bool hasFooter: root.actionVisible || root.footerText.length > 0

    implicitHeight: top.implicitHeight + (root.hasFooter ? footer.height + 12 : 0) + root.padding * 2
    radius: Colors.radiusLarge
    color: Colors.surfaceHigh

    Column {
        id: top
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: 10

        Item {
            width: parent.width
            height: heading.implicitHeight

            Column {
                id: heading
                width: parent.width - 28
                spacing: 2

                Row {
                    visible: root.value.length > 0
                    spacing: 3

                    StyledText {
                        id: valueText
                        text: root.value
                        font.bold: true
                        font.pixelSize: Config.fontSize + 14
                        font.family: Config.monoFontFamily
                    }
                    StyledText {
                        anchors.baseline: valueText.baseline
                        text: root.unit
                        opacity: 0.6
                        font.pixelSize: Config.fontSize - 2
                    }
                }
                StyledText {
                    visible: root.value.length === 0 && root.title.length > 0
                    text: root.title
                    font.weight: Font.DemiBold
                    font.pixelSize: Config.fontSize + 1
                }
                StyledText {
                    visible: root.label.length > 0
                    width: parent.width
                    text: root.label
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                anchors.right: parent.right
                anchors.top: parent.top
                visible: root.icon.length > 0
                icon: root.icon
                font.pixelSize: 18
                color: root.iconColor
                opacity: Qt.colorEqual(root.iconColor, Colors.text) ? 0.5 : 1
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: 8
        }
    }

    Item {
        id: footer
        visible: root.hasFooter
        x: root.padding
        width: root.width - root.padding * 2
        height: Math.max(footerLabel.implicitHeight, action.implicitHeight)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding

        StyledText {
            id: footerLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (action.visible ? action.width + 10 : 0)
            text: root.footerText
            opacity: 0.6
            font.pixelSize: Config.fontSize - 3
            elide: Text.ElideRight
        }

        Chip {
            id: action
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.actionVisible
            enabled: root.actionEnabled
            text: root.actionText
            onClicked: root.actionTriggered()
        }
    }
}
