import QtQuick
import "../../services"
import "../../components"

SettingsPreviewPage {
    id: root
    title: "Turntable"
    icon: "album"
    readonly property var track: MediaSession.state.track
    readonly property var optionKeys: ["turntableDesign", "turntableScale", "turntableFinish", "turntablePlatter", "turntableArtworkSize", "turntableSpin", "turntableSpeed", "turntableTonearm", "turntableTrackProgress"]

    previewComponent: Component {
        Item {
            implicitHeight: preview.implicitHeight + 24
            Turntable {
                id: preview
                objectName: "turntablePreview"
                anchors.centerIn: parent
                size: 140
                artUrl: root.track ? root.track.artUrl : ""
                playing: MediaSession.state.playback.playing
                progress: root.track && root.track.duration > 0 ? root.track.position / root.track.duration : 0
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        SectionTitle {
            title: "Appearance"
            subtitle: "Applies to Media and the lock screen. The preview follows current playback."
        }
        SettingsCard {
            OptionChoice {
                target: Config
                option: "turntableDesign"
                icon: "album"
                label: "Design"
                choices: [
                    { value: "classic", label: "Classic" },
                    { value: "studio", label: "Studio" },
                    { value: "minimal", label: "Minimal" },
                    { value: "sleeve", label: "Sleeve" }
                ]
            }
            OptionChoice {
                objectName: "turntableFinishControl"
                target: Config
                option: "turntableFinish"
                enabled: Config.turntableDesign !== "minimal"
                opacity: enabled ? 1 : 0.4
                icon: "palette"
                label: Config.turntableDesign === "sleeve" ? "Label finish" : "Base finish"
                choices: [
                    { value: "cream", label: "Cream" },
                    { value: "theme", label: "Theme" },
                    { value: "charcoal", label: "Charcoal" }
                ]
            }
            OptionSlider {
                target: Config
                option: "turntableScale"
                icon: "resize"
                label: "Size"
                format: v => Math.round(v) + "%"
            }
            OptionSlider {
                target: Config
                option: "turntableArtworkSize"
                icon: "album"
                label: Config.turntableDesign === "sleeve" ? "Label size" : "Artwork size"
                format: v => Math.round(v) + "%"
                last: true
            }
        }

        SectionTitle { title: "Platter color" }
        SettingsCard {
            Column {
                width: parent.width
                padding: 14
                spacing: 10

                Repeater {
                    model: ["Solid", "Gradient"]
                    Column {
                        id: presetGroup
                        required property string modelData
                        width: parent.width - parent.padding * 2
                        spacing: 8

                        StyledText { text: presetGroup.modelData; color: Colors.subtext; font.pixelSize: Config.fontSize - 1 }
                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: Config.turntablePlatterPresets.filter(preset => !!preset.endColor === (presetGroup.modelData === "Gradient"))
                                Chip {
                                    id: presetChip
                                    required property var modelData
                                    objectName: "turntablePlatter_" + modelData.value
                                    text: modelData.label
                                    active: Config.turntablePlatter === modelData.value
                                    onClicked: Config.setOption("turntablePlatter", modelData.value)

                                    Rectangle {
                                        width: 16
                                        height: width
                                        radius: width / 2
                                        color: presetChip.modelData.color
                                        gradient: presetChip.modelData.endColor ? swatchGradient : null
                                        antialiasing: true
                                        Gradient {
                                            id: swatchGradient
                                            GradientStop { position: 0; color: presetChip.modelData.color }
                                            GradientStop { position: 1; color: presetChip.modelData.endColor || presetChip.modelData.color }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        SectionTitle {
            title: "Motion"
            subtitle: Config.reducedMotion ? "Motion is paused by Reduce motion." : "The record spins during playback and coasts to a stop on pause."
        }
        SettingsCard {
            OptionToggle { target: Config; option: "turntableSpin"; icon: "rotate_right"; label: "Record rotation" }
            OptionChoice {
                objectName: "turntableSpeedControl"
                target: Config
                option: "turntableSpeed"
                icon: "speed"
                label: "Speed"
                enabled: Config.turntableSpin && !Config.reducedMotion
                opacity: enabled ? 1 : 0.4
                last: true
                choices: [
                    { value: "33", label: "33⅓ RPM" },
                    { value: "45", label: "45 RPM" }
                ]
            }
        }

        SectionTitle { title: "Tonearm" }
        SettingsCard {
            OptionToggle { target: Config; option: "turntableTonearm"; icon: "album"; label: "Show tonearm" }
            OptionToggle {
                objectName: "turntableTrackingControl"
                target: Config
                option: "turntableTrackProgress"
                icon: "moving"
                label: "Follow track progress"
                enabled: Config.turntableTonearm
                opacity: enabled ? 1 : 0.4
                last: true
            }
        }

        Chip {
            anchors.right: parent.right
            text: "Reset"
            inactiveTint: Colors.surfaceHigh
            onClicked: Config.resetOptions(root.optionKeys)
        }
    }
}
