import QtQuick
import "../services"

Text {
    property string icon: ""
    property bool filled: false

    textFormat: Text.PlainText
    text: icon
    font.family: Config.iconFontFamily
    font.pixelSize: 18
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 400, "GRAD": 0, "opsz": 24 })
    color: Colors.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
