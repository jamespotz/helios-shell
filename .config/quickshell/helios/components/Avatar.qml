import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../services"

// Circular user avatar sourced from ~/.face/face.jpg (standard Linux avatar
// location, e.g. what AccountsService/lightdm greeters use). Falls back to
// a person icon when no image is present. Uses ClippingRectangle rather
// than a hidden Image + MultiEffect mask — same primitive MediaCard/IdleBump
// standardized on after the mask approach rendered an empty texture.
//
// The picker shells out to `zenity --file-selection` instead of
// QtQuick.Dialogs' FileDialog — that module's native backend goes through
// the xdg-desktop-portal, which this layer-shell shell can't reliably parent
// a dialog to, so it never opened. zenity is a plain top-level GTK window
// with no portal round-trip and is already installed on this machine.
Item {
    id: root
    property int size: 44
    property bool editable: false

    readonly property string facePath: Quickshell.env("HOME") + "/.face/face.jpg"

    width: size
    height: size

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: Colors.surfaceHigh
        clip: true

        Image {
            id: image
            anchors.fill: parent
            source: "file://" + root.facePath
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            mipmap: true
            smooth: true
            cache: false
            asynchronous: true
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            icon: "person"
            font.pixelSize: root.size * 0.55
            color: Colors.subtext
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "black"
            opacity: hoverArea.containsMouse ? 0.4 : 0
            visible: root.editable
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: root.editable && hoverArea.containsMouse
            icon: "photo_camera"
            font.pixelSize: root.size * 0.4
            color: "white"
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        visible: root.editable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Settings is an Overlay-layer surface, always above normal
            // toplevels, so zenity's picker would render behind it and be
            // unclickable. Bridge.avatarPickerOpen tells it to hide itself
            // for the picker's lifetime.
            Bridge.avatarPickerOpen = true;
            pickProc.running = true;
        }
    }

    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--title=Choose profile photo",
            "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = text.trim();
                if (!picked) return;
                copyProc.command = ["cp", picked, root.facePath];
                copyProc.running = true;
            }
        }
        onExited: Bridge.avatarPickerOpen = false;
    }

    Process {
        id: copyProc
        onExited: {
            // Force a real reload: with cache disabled, clearing then
            // restoring the same URL still re-reads the file from disk.
            image.source = "";
            image.source = "file://" + root.facePath;
        }
    }
}
