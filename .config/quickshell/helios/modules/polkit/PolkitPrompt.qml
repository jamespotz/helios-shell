import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

// Apple-style authentication sheet — small centered card, no chrome beyond
// what the request needs. One flow at a time; the agent (PolkitAgent.qml)
// recreates this fresh for each request.
PanelWindow {
    id: root

    required property AuthFlow flow

    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:polkit"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    Scrim {
        active: true
        dimOpacity: 0.5
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.flow.cancelAuthenticationRequest()

        Item {
            id: card
            width: 360
            height: col.implicitHeight + 32
            anchors.centerIn: parent

            transform: Translate { id: shake }

            SequentialAnimation {
                running: root.flow.failed
                NumberAnimation { target: shake; property: "x"; from: 0; to: -8; duration: 45 }
                NumberAnimation { target: shake; property: "x"; from: -8; to: 8; duration: 45 }
                NumberAnimation { target: shake; property: "x"; from: 8; to: -8; duration: 45 }
                NumberAnimation { target: shake; property: "x"; from: -8; to: 0; duration: 45 }
            }

            PanelBackground {
                anchors.fill: parent
                border.color: root.flow.failed || root.flow.supplementaryIsError
                    ? Colors.danger : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)
                Behavior on border.color { ColorAnimation { duration: Config.animFast } }
            }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 10

                    MaterialIcon { icon: "lock"; font.pixelSize: 22; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }

                    Column {
                        width: parent.width - 32
                        spacing: 1
                        StyledText {
                            width: parent.width
                            text: root.flow.message || "Authentication required"
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                        }
                        StyledText {
                            visible: text.length > 0
                            width: parent.width
                            text: root.flow.actionId
                            color: Colors.subtext
                            font.pixelSize: Config.fontSize - 2
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                StyledText {
                    visible: root.flow.supplementaryMessage.length > 0
                    width: parent.width
                    text: root.flow.supplementaryMessage
                    color: root.flow.supplementaryIsError ? Colors.danger : Colors.subtext
                    font.pixelSize: Config.fontSize - 1
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    visible: root.flow.isResponseRequired
                    width: parent.width
                    height: 40
                    radius: height / 2
                    color: Colors.surfaceHigh

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colors.text
                        font.family: Config.fontFamily
                        font.pixelSize: Config.fontSize
                        clip: true
                        echoMode: root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        focus: root.flow.isResponseRequired

                        Keys.onReturnPressed: submitButton.clicked()

                        StyledText {
                            visible: input.text.length === 0
                            text: root.flow.inputPrompt || "Password"
                            color: Colors.subtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8
                    layoutDirection: Qt.RightToLeft

                    PrimaryButton {
                        id: submitButton
                        text: "Authenticate"
                        active: true
                        enabled: root.flow.isResponseRequired && input.text.length > 0
                        onClicked: { root.flow.submit(input.text); input.text = ""; }
                    }
                    PrimaryButton {
                        text: "Cancel"
                        onClicked: root.flow.cancelAuthenticationRequest()
                    }
                }
            }
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
