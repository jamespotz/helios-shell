import QtQuick

Item {
    implicitWidth: 320
    implicitHeight: controls.implicitHeight
    FocusTimerControls {
        id: controls
        width: parent.width
    }
}
