import QtQuick
import "../../services"
import "../../components"

// Settings > Date & time — the clock format every clock in the shell uses.
Item {
    id: root

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        Row {
            spacing: 8
            bottomPadding: 10
            MaterialIcon { icon: "schedule"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Date & time"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        SectionTitle {
            title: "Clock format"
            subtitle: "Applies to every clock in the shell, including the lock screen."
        }

        SettingsCard {
            OptionToggle { target: Config; option: "use24HourClock"; icon: "schedule"; label: "24-hour time" }
            OptionToggle {
                target: Config
                option: "clockAmPmUppercase"
                icon: "text_fields"
                label: "Uppercase AM/PM"
                last: true
                enabled: !Config.use24HourClock
                opacity: enabled ? 1 : 0.4
            }
        }
    }
}
