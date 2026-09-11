import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    onActiveChanged: Bridge.locked = active

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

                // Session-lock surfaces are opaque by design (the compositor
                // won't show anything behind them), so "transparency" here
                // means showing the real wallpaper through a dim tint rather
                // than a flat color — same translucent-panel convention
                // (Colors.panelOpacity) SettingsWindow's card uses.
                // Slow Ken Burns drift — calm, ambient motion rather than
                // decoration, matching the 60s-per-cycle pace the orbit
                // views use elsewhere. Clipped so the zoom never reveals an
                // edge, and skipped entirely under reduced motion.
                Item {
                    anchors.fill: parent
                    clip: true

                    Image {
                        id: wallpaperImage
                        anchors.fill: parent
                        visible: !Wallpaper.isVideo && Wallpaper.source.length > 0
                        source: visible ? Wallpaper.source : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        transformOrigin: Item.Center

                        SequentialAnimation on scale {
                            running: wallpaperImage.visible && !Config.reducedMotion
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 1.06; duration: 60000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.06; to: 1.0; duration: 60000; easing.type: Easing.InOutSine }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !Wallpaper.isVideo && Wallpaper.source.length > 0
                    color: Colors.background
                    opacity: 1 - Colors.panelOpacity
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 22

                    Avatar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 84
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

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        visible: Weather.available

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: Weather.icon
                            color: Colors.accent
                            font.pixelSize: 15
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Config.fontSize + 1
                            color: Colors.subtext
                            text: Math.round(Weather.tempC) + "°  " + Weather.condition
                        }
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

                // Power menu — a plain list popover (not PowerMenuIsland's
                // square cards), same second-tap-to-confirm safety on the
                // destructive entries, same dispatch commands.
                Item {
                    id: powerMenu
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 24
                    width: powerButton.width
                    height: powerButton.height

                    property bool open: false
                    property string pendingAction: ""

                    readonly property var actions: [
                        { id: "logout", icon: "logout", label: "Logout" },
                        { id: "restart", icon: "restart_alt", label: "Restart" },
                        { id: "poweroff", icon: "power_settings_new", label: "Power Off" }
                    ]

                    function run(id) {
                        if (id === "logout")
                            // See PowerMenuIsland.qml: this Hyprland config wraps
                            // dispatch payloads through a Lua plugin, so the
                            // bare "exit" dispatcher name fails silently.
                            Hyprland.dispatch("hl.dsp.exit()");
                        else if (id === "restart")
                            Quickshell.execDetached(["systemctl", "reboot"]);
                        else if (id === "poweroff")
                            Quickshell.execDetached(["systemctl", "poweroff"]);
                    }

                    PanelBackground {
                        id: menuCard
                        anchors.right: powerButton.right
                        anchors.bottom: powerButton.top
                        anchors.bottomMargin: 12
                        width: 180
                        height: menuColumn.implicitHeight + 8
                        visible: powerMenu.open

                        Column {
                            id: menuColumn
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2

                            Repeater {
                                model: powerMenu.actions

                                HoverRow {
                                    id: actionRow
                                    required property var modelData
                                    width: menuColumn.width
                                    height: 40
                                    highlighted: powerMenu.pendingAction === actionRow.modelData.id
                                    onClicked: {
                                        if (powerMenu.pendingAction === actionRow.modelData.id) {
                                            powerMenu.open = false;
                                            powerMenu.pendingAction = "";
                                            powerMenu.run(actionRow.modelData.id);
                                        } else {
                                            powerMenu.pendingAction = actionRow.modelData.id;
                                        }
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        MaterialIcon {
                                            icon: actionRow.modelData.icon
                                            font.pixelSize: 16
                                            color: actionRow.highlighted ? Colors.danger : Colors.text
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: actionRow.highlighted ? "Confirm " + actionRow.modelData.label + "?" : actionRow.modelData.label
                                            color: actionRow.highlighted ? Colors.danger : Colors.text
                                            font.weight: actionRow.highlighted ? Font.Medium : Font.Normal
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    IconButton {
                        id: powerButton
                        icon: "power_settings_new"
                        iconSize: 18
                        onClicked: { powerMenu.open = !powerMenu.open; powerMenu.pendingAction = ""; }
                    }
                }
            }
        }
    }
}
