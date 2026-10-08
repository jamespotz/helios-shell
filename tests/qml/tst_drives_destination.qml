import QtQuick
import Quickshell
import Quickshell.Io
import services
import "modules/island"
ShellRoot {
    id: root
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    property Timer exitDelay: Timer { interval: 100; onTriggered: terminator.running = true }
    Component { id: destinationComponent; DrivesDestination {} }
    function verify(v, message) { if (!v) throw new Error(message); }
    Component.onCompleted: {
        try {
            const destination = destinationComponent.createObject(root);
            verify(destination !== null && destination.implicitHeight > 0, "destination loads");
            verify(IslandNavigation.resolve("drives") !== null, "registered for launcher");
            RemovableDrives.busy = true;
            verify(!RemovableDrives.mount("/dev/not-real"), "reject overlapping operations");
            RemovableDrives.busy = false;
            RemovableDrives.drives = [];
            verify(destination.implicitHeight > 0, "empty state");
            RemovableDrives.error = "permission denied";
            RemovableDrives.drives = [{path: "/dev/sdz", label: "USB", sizeBytes: 4096, partitions:[{path: "/dev/sdz1", label: "Data", sizeBytes: 1024, filesystem: "ext4", mountPoints: [], supported: true}]}];
            verify(destination.implicitHeight > 0, "drive/error state");
            console.warn("DRIVES_DESTINATION_TEST_PASS");
        } catch (e) { console.error("DRIVES_DESTINATION_TEST_FAIL:", e.toString()); }
        exitDelay.start();
    }
}
