import QtQuick
import "../../services"
import "../../components"

Item {
    id: root
    implicitWidth: 320
    implicitHeight: col.implicitHeight

    function applyLocation() {
        const text = locationInput.text.trim();
        if (!text || (text.includes(",") && /^[+\d.,\s-]+$/.test(text))) {
            Weather.setLocation(text);
            Weather.searchLocations("");
        } else {
            Weather.searchLocations(text);
        }
    }

    function chooseLocation(place) {
        Weather.selectLocation(place);
        locationInput.text = Weather.locationName || Weather.locationOverride;
        locationInput.focusInput();
    }

    Component.onDestruction: Weather.searchLocations("")
    Connections {
        target: Weather
        function onSearchResultsChanged() { cities.currentIndex = Weather.searchResults.length ? 0 : -1; }
    }

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
            subtitle: "Search for a city or enter latitude,longitude. Auto-detect uses your IP. Also used for Night Light's sunset-to-sunrise schedule."
        }

        SettingsCard {
            Column {
                width: parent.width - 28
                x: 14
                topPadding: 12
                bottomPadding: 12
                spacing: 12

                SearchField {
                    id: locationInput
                    objectName: "weatherLocationInput"
                    width: parent.width
                    height: 36
                    color: Colors.surface
                    placeholder: "City or latitude,longitude"
                    text: Weather.locationName || Weather.locationOverride
                    onTextChanged: Weather.searchLocations("")
                    onAccepted: {
                        if (cities.currentIndex >= 0 && Weather.searchResults.length)
                            root.chooseLocation(Weather.searchResults[cities.currentIndex]);
                        else root.applyLocation();
                    }
                    onEscapePressed: Weather.searchLocations("")
                    onDownPressed: if (cities.count) cities.currentIndex = Math.min(cities.count - 1, cities.currentIndex + 1)
                    onUpPressed: if (cities.count) cities.currentIndex = Math.max(0, cities.currentIndex - 1)
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 2
                        border.color: Colors.accent
                        visible: locationInput.inputActiveFocus
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 8
                    Chip { objectName: "weatherSearchButton"; text: "Search / Apply"; active: true; onClicked: root.applyLocation() }
                    Chip {
                        text: "Auto-detect"
                        onClicked: { locationInput.text = ""; Weather.searchLocations(""); Weather.setLocation(""); }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: Weather.searching || Weather.searchError.length > 0
                    wrapMode: Text.WordWrap
                    color: Weather.searchError ? Colors.error : Colors.subtext
                    text: Weather.searching ? "Searching…" : Weather.searchError
                    font.pixelSize: Config.fontSize - 2
                }

                ListView {
                    id: cities
                    objectName: "weatherCityResults"
                    width: parent.width
                    height: Math.min(contentHeight, 190)
                    visible: count > 0
                    model: Weather.searchResults
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        id: cityRow
                        required property var modelData
                        required property int index
                        width: cities.width
                        height: 38
                        radius: Colors.radiusSmall
                        color: cityHover.hovered || cities.currentIndex === index ? Colors.surface : "transparent"
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: Weather.locationLabel(modelData)
                        Accessible.onPressAction: root.chooseLocation(modelData)
                        Keys.onReturnPressed: root.chooseLocation(modelData)
                        Keys.onSpacePressed: root.chooseLocation(modelData)
                        onActiveFocusChanged: if (activeFocus) cities.currentIndex = index
                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: Weather.locationLabel(cityRow.modelData)
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 2
                            border.color: Colors.accent
                            visible: cityRow.activeFocus
                        }
                        HoverHandler { id: cityHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.chooseLocation(cityRow.modelData)
                        }
                    }
                    ScrollIndicator { target: cities }
                }

                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Colors.subtext
                    font.pixelSize: Config.fontSize - 2
                    text: Weather.loading ? "Loading…"
                        : Weather.available ? "Now: " + Weather.formatTemperature(Weather.tempC, true) + ", " + Weather.condition
                            + (Weather.location ? " · " + Weather.location : "")
                        : "No weather data yet"
                }
            }
        }

        SectionTitle { title: "Units"; subtitle: "Applies to Weather throughout the shell." }
        SettingsCard {
            SettingsRow {
                icon: "device_thermostat"
                label: "Temperature"
                Row {
                    spacing: 4
                    Chip { text: "°C"; active: Weather.temperatureUnit === "celsius"; onClicked: Weather.setOption("temperatureUnit", "celsius") }
                    Chip { objectName: "weatherFahrenheit"; text: "°F"; active: Weather.temperatureUnit === "fahrenheit"; onClicked: Weather.setOption("temperatureUnit", "fahrenheit") }
                }
            }
            SettingsRow {
                icon: "air"
                label: "Wind"
                last: true
                Row {
                    spacing: 4
                    Chip { text: "km/h"; active: Weather.windUnit === "kmh"; onClicked: Weather.setOption("windUnit", "kmh") }
                    Chip { text: "mph"; active: Weather.windUnit === "mph"; onClicked: Weather.setOption("windUnit", "mph") }
                    Chip { text: "m/s"; active: Weather.windUnit === "ms"; onClicked: Weather.setOption("windUnit", "ms") }
                }
            }
        }

        SectionTitle { title: "Updates" }
        SettingsCard {
            Column {
                width: parent.width - 28
                x: 14
                topPadding: 12
                bottomPadding: 12
                spacing: 12
                StyledText { text: "Refresh interval"; color: Colors.subtext; font.pixelSize: Config.fontSize - 2 }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: [10, 20, 30, 60]
                        Chip {
                            required property int modelData
                            text: modelData + " min"
                            active: Weather.refreshMinutes === modelData
                            onClicked: Weather.setOption("refreshMinutes", modelData)
                        }
                    }
                }
                Flow {
                    width: parent.width
                    spacing: 8
                    Chip {
                        objectName: "weatherRefreshButton"
                        text: Weather.loading ? "Refreshing…" : "Refresh"
                        enabled: !Weather.loading
                        onClicked: Weather.refresh()
                    }
                    StyledText {
                        height: 28
                        verticalAlignment: Text.AlignVCenter
                        text: Weather.lastUpdated ? "Updated " + Qt.formatDateTime(new Date(Weather.lastUpdated), Config.timeFormat) : "Not updated yet"
                        color: Colors.subtext
                        font.pixelSize: Config.fontSize - 2
                    }
                }
                StyledText {
                    width: parent.width
                    visible: Weather.error.length > 0
                    wrapMode: Text.WordWrap
                    color: Colors.error
                    text: Weather.error
                    font.pixelSize: Config.fontSize - 2
                }
            }
        }

        SectionTitle { title: "Appearance"; subtitle: Config.reducedMotion ? "Animations are paused by Reduce motion." : "Weather effects in the Island destination." }
        SettingsCard {
            OptionToggle { target: Weather; option: "animationsEnabled"; icon: "animation"; label: "Weather animations"; last: true }
        }
    }
}
