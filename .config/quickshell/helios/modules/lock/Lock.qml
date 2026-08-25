import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../../services"
import "../../components"

// Lock only works reliably when the WlSessionLock object sets `locked = true`
// inside its OWN Component.onCompleted — confirmed by extensive live testing
// on this machine's Hyprland: a long-lived WlSessionLock that gets `locked`
// flipped true later (via a signal from a click, a Timer, anything external
// to its own construction) silently never engages the compositor lock at
// all, even though there's no error anywhere. A *freshly constructed*
// WlSessionLock that locks itself in its own onCompleted works every time,
// regardless of how long the shell had already been running. So instead of
// one WlSessionLock sitting dormant for the shell's whole lifetime, a Loader
// creates a brand new one — and lets it self-destruct — each time.
Loader {
    id: root
    active: false

    Connections {
        target: Bridge
        function onLockRequested() { root.active = true }
    }

    sourceComponent: WlSessionLock {
        id: lock

        Component.onCompleted: lock.locked = true
        onLockedChanged: if (!lock.locked) root.active = false

        surface: Component {
            WlSessionLockSurface {
                id: surface
                color: Colors.background

                Column {
                    anchors.centerIn: parent
                    spacing: 22

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: "lock"
                        font.pixelSize: 40
                    }

                    StyledText {
                        id: timeText
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 44
                        font.bold: true

                        SystemClock {
                            id: clock
                            precision: SystemClock.Minutes
                        }
                        text: Qt.formatDateTime(clock.date, Config.timeFormat)
                    }

                    Rectangle {
                        width: 260
                        height: 46
                        radius: Colors.radiusSmall
                        color: Colors.surfaceHigh
                        anchors.horizontalCenter: parent.horizontalCenter
                        border.width: pwInput.activeFocus ? 1 : 0
                        border.color: Colors.accent

                        TextInput {
                            id: pwInput
                            anchors.fill: parent
                            anchors.margins: 14
                            echoMode: TextInput.Password
                            color: Colors.text
                            font.family: Config.fontFamily
                            font.pixelSize: Config.fontSize + 1
                            focus: true
                            enabled: !pam.active || !pam.responseRequired

                            Keys.onReturnPressed: {
                                pwInput.enabled = false;
                                pam.start();
                            }
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pam.message.length > 0 ? pam.message : (!pwInput.enabled ? "Checking…" : "")
                        color: pam.messageIsError ? Colors.danger : Colors.subtext
                        visible: text.length > 0
                    }
                }

                PamContext {
                    id: pam
                    config: Config.pamService
                    active: true

                    onResponseRequiredChanged: {
                        if (responseRequired)
                            respond(pwInput.text);
                    }

                    onCompleted: result => {
                        if (result === PamResult.Success) {
                            lock.locked = false;
                        } else {
                            pwInput.text = "";
                            pwInput.enabled = true;
                            pwInput.forceActiveFocus();
                        }
                    }
                }

                Component.onCompleted: pwInput.forceActiveFocus()

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: pwInput.forceActiveFocus()
                }
            }
        }
    }
}
