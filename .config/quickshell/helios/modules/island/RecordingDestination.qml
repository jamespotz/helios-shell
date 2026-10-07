import QtQuick
import QtQuick.Controls
import "../../services"
import "../../components"

Item {
    id: root
    property string targetScreen: ""
    readonly property real uiScale: Config.fontSize / 13
    readonly property bool dark: Themes.isDark(Colors.background)
    // Reference palette. Keep its light variant when the shell uses a light theme.
    readonly property color textPrimary: root.dark ? "#f2f3f7" : "#161923"
    readonly property color textSecondary: root.dark ? "#868fa8" : "#656d82"
    readonly property color textTertiary: root.dark ? "#5c6378" : "#9aa0b4"
    readonly property color recordingColor: root.dark ? "#ff4d6d" : "#e0294a"
    readonly property color raisedColor: root.dark ? "#1a1e2c" : "#f5f6fa"
    readonly property color hoverColor: root.dark ? "#202537" : "#ebedf3"
    readonly property color focusColor: root.dark ? "#2fe0c4" : "#17b89d"

    implicitWidth: 272 * root.uiScale
    implicitHeight: openButton.y + openButton.height

    Item {
        id: status
        width: parent.width
        height: 21.025 * root.uiScale

        Item {
            id: dot
            width: 10 * root.uiScale
            height: width
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: halo
                anchors.centerIn: parent
                width: 22 * root.uiScale
                height: width
                radius: width / 2
                color: root.recordingColor
                visible: ScreenRecorder.recording && !Config.reducedMotion
                opacity: 0
                SequentialAnimation {
                    running: halo.visible && root.visible
                    loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation { target: halo; property: "scale"; from: 0.6; to: 1.6; duration: 1260; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.7, 0.3, 1, 1, 1] }
                        NumberAnimation { target: halo; property: "opacity"; from: 0.35; to: 0; duration: 1260; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.7, 0.3, 1, 1, 1] }
                    }
                    PauseAnimation { duration: 540 }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: ScreenRecorder.recording ? root.recordingColor : root.textTertiary
                antialiasing: true
            }
        }
        StyledText {
            anchors.left: dot.right
            anchors.leftMargin: 12 * root.uiScale
            anchors.right: elapsed.left
            anchors.rightMargin: 12 * root.uiScale
            anchors.verticalCenter: parent.verticalCenter
            text: ScreenRecorder.recording ? qsTr("Recording") : qsTr("Stopped at")
            color: root.textPrimary
            font.pixelSize: 14.5 * root.uiScale
            font.weight: 560
            font.letterSpacing: 0
            elide: Text.ElideRight
        }
        StyledText {
            id: elapsed
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: ScreenRecorder.elapsedLabel
            color: root.textSecondary
            font.family: Config.monoFontFamily
            font.pixelSize: 14 * root.uiScale
            font.weight: 560
            font.letterSpacing: 0.14 * root.uiScale
        }
    }

    // AbstractButton supplies pointer, keyboard, focus, and accessibility states.
    // The two reference actions share mechanics but have different visual weight.
    component RecordingAction: AbstractButton {
        id: action
        property bool secondary: false
        readonly property color ink: action.secondary
            ? (action.hovered ? root.textPrimary : root.textSecondary)
            : (action.enabled ? root.recordingColor : root.textSecondary)
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Keys.onReturnPressed: action.clicked()
        Keys.onEnterPressed: action.clicked()
        HoverHandler { enabled: action.enabled; cursorShape: Qt.PointingHandCursor }
        implicitHeight: (action.secondary ? 43.575 : 44) * root.uiScale
        scale: !action.secondary && action.down && !Config.reducedMotion ? 0.985 : 1
        Behavior on scale { enabled: !Config.reducedMotion; Spring {} }
        background: Rectangle {
            radius: (action.secondary ? 8 : 12) * root.uiScale
            color: action.secondary ? (action.hovered ? root.hoverColor : "transparent")
                : !action.enabled ? root.raisedColor
                : Qt.alpha(root.recordingColor, action.hovered ? (root.dark ? 0.248 : 0.22) : (root.dark ? 0.14 : 0.1))
            Behavior on color { enabled: !Config.reducedMotion; ColorAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.7, 0.3, 1, 1, 1] } }
            Rectangle {
                anchors.fill: parent
                anchors.margins: action.secondary ? 2 * root.uiScale : -4 * root.uiScale
                radius: parent.radius + (action.secondary ? -2 : 4) * root.uiScale
                color: "transparent"
                border.width: 2 * root.uiScale
                border.color: Qt.alpha(action.secondary ? root.focusColor : root.recordingColor, 0.55)
                visible: action.visualFocus
            }
        }
        contentItem: Item {
            Row {
                x: action.secondary ? 8 * root.uiScale : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: (action.secondary ? 12 : 8) * root.uiScale
                Image {
                    width: (action.secondary ? 16 : 14) * root.uiScale
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize.width: width
                    sourceSize.height: height
                    source: "data:image/svg+xml," + encodeURIComponent(action.secondary
                        ? '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + root.textTertiary + '" stroke-width="2"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10.5l5-3v9l-5-3z"/></svg>'
                        : '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="' + action.ink + '"><rect x="5" y="5" width="14" height="14" rx="2"/></svg>')
                }
                StyledText {
                    text: action.text
                    width: Math.min(implicitWidth, Math.max(0, action.availableWidth - (action.secondary ? 44 : 38) * root.uiScale))
                    anchors.verticalCenter: parent.verticalCenter
                    color: action.ink
                    font.pixelSize: (action.secondary ? 13.5 : 14.5) * root.uiScale
                    font.weight: action.secondary ? Font.Medium : Font.DemiBold
                    font.letterSpacing: 0
                    elide: Text.ElideRight
                }
            }
        }
    }

    RecordingAction {
        id: stopButton
        y: status.height + 24 * root.uiScale
        width: parent.width
        text: ScreenRecorder.recording ? qsTr("Stop recording") : qsTr("Recording stopped")
        enabled: ScreenRecorder.recording
        onClicked: ScreenRecorder.stop()
    }
    RecordingAction {
        id: openButton
        y: stopButton.y + stopButton.height + 8 * root.uiScale
        width: parent.width
        secondary: true
        text: qsTr("Open Recorder")
        onClicked: {
            IslandNavigation.closeSatellite(root.targetScreen);
            IslandNavigation.show(root.targetScreen, "recorder");
        }
    }
}
