import QtQuick
import "../../services"
import "../../components"

// Hyprland config editor shell — SegmentedControl switches sub-sections,
// each its own file (per AGENTS.md: no file grows unbounded) so General,
// Appearance, Animations, Input, Keybinds, Window rules, Layer rules, and
// Advanced can each own their field list independently.
Item {
    id: root

    implicitWidth: 520
    implicitHeight: col.implicitHeight

    property string activeSection: "general"

    readonly property var sections: [
        { value: "general", label: "General" },
        { value: "appearance", label: "Appearance" },
        { value: "animations", label: "Animations" },
        { value: "input", label: "Input" },
        { value: "keybinds", label: "Keybinds" },
        { value: "windowrules", label: "Window rules" },
        { value: "layerrules", label: "Layer rules" },
        { value: "advanced", label: "Advanced" }
    ]

    Column {
        id: col
        width: parent.width
        spacing: 20

        Row {
            width: parent.width
            spacing: 10
            MaterialIcon { icon: "settings_applications"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText {
                text: "Hyprland"
                font.pixelSize: Config.fontSize + 4
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        SegmentedControl {
            model: root.sections
            currentValue: root.activeSection
            onActivated: v => root.activeSection = v
        }

        Loader {
            width: parent.width
            sourceComponent: root.activeSection === "general" ? generalSection
                : root.activeSection === "appearance" ? appearanceSection
                : root.activeSection === "animations" ? animationsSection
                : root.activeSection === "input" ? inputSection
                : root.activeSection === "keybinds" ? keybindsSection
                : root.activeSection === "windowrules" ? windowRulesSection
                : root.activeSection === "layerrules" ? layerRulesSection
                : advancedSection
        }
    }

    Component { id: generalSection; HyprlandGeneralSection { width: col.width } }
    Component { id: appearanceSection; HyprlandAppearanceSection { width: col.width } }
    Component { id: animationsSection; HyprlandAnimationsSection { width: col.width } }
    Component { id: inputSection; HyprlandInputSection { width: col.width } }
    Component { id: keybindsSection; HyprlandKeybindsSection { width: col.width } }
    Component { id: windowRulesSection; HyprlandWindowRulesSection { width: col.width } }
    Component { id: layerRulesSection; HyprlandLayerRulesSection { width: col.width } }
    Component { id: advancedSection; HyprlandAdvancedSection { width: col.width } }
}
