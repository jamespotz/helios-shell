import QtQuick
import "../services"

// Grouped-list card for Settings pages: rows sit inside one rounded card,
// with a hairline between rows (SettingsRow/SettingsSlider draw it) and a
// plain gap between cards.
Rectangle {
    default property alias content: inner.children

    width: parent ? parent.width : 0
    implicitHeight: inner.implicitHeight
    height: implicitHeight
    radius: Colors.radiusLarge
    color: Colors.surfaceHigh

    Column {
        id: inner
        width: parent.width
    }
}
