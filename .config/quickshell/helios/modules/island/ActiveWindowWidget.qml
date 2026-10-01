import QtQuick
import Quickshell.Hyprland
import "../../components"

StyledText {
    text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
    elide: Text.ElideRight
    opacity: 0.8
}
