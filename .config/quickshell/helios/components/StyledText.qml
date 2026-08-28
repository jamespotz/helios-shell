import QtQuick
import "../services"

// Base text element — uses Inter (Apple SF Pro equivalent on Linux) with
// native rendering for subpixel clarity. All text inherits from this.
Text {
    textFormat: Text.PlainText
    color: Colors.text
    font.family: Config.fontFamily
    font.pixelSize: Config.fontSize
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    // Apple uses -0.2 to -0.4 letter spacing at small sizes for tightness
    font.letterSpacing: -0.2
}
