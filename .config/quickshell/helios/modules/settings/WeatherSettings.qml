import QtQuick
import "../../services"
import "../../components"

// Settings > Weather — the location Weather (and Night Light's
// sunset-to-sunrise schedule) uses.
Item {
    id: root

    property string draft: Weather.locationOverride

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        Row {
            spacing: 8
            bottomPadding: 10
            MaterialIcon { icon: "partly_cloudy_day"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Weather"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        SectionTitle {
            title: "Location"
            subtitle: "City name, or \"lat,long\". Leave empty to auto-detect from this machine's IP. Also used for Night Light's sunset-to-sunrise schedule."
        }

        SettingsCard {
            Column {
                width: parent.width - 28
                x: 14
                topPadding: 12
                bottomPadding: 12
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: height / 2
                    color: Colors.surface

                    TextInput {
                        id: weatherInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        color: Colors.text
                        font.family: Config.fontFamily
                        font.pixelSize: Config.fontSize
                        clip: true
                        text: root.draft
                        verticalAlignment: TextInput.AlignVCenter

                        onTextChanged: root.draft = text
                        Keys.onReturnPressed: Weather.setLocation(root.draft)

                        StyledText {
                            visible: weatherInput.text.length === 0
                            text: "e.g. Tokyo or 35.68,139.69"
                            opacity: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Row {
                    spacing: 8

                    Chip { text: "Apply"; active: true; onClicked: Weather.setLocation(root.draft) }
                    Chip { text: "Auto-detect"; onClicked: { root.draft = ""; Weather.setLocation(""); } }
                }

                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                    font.pixelSize: Config.fontSize - 2
                    text: Weather.loading ? "Loading…"
                        : Weather.available ? "Now: " + Math.round(Weather.tempC) + "°C, " + Weather.condition
                            + (Weather.location ? " — " + Weather.location : "")
                        : "No data yet"
                }
            }
        }
    }
}
