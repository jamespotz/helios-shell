pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var drives: []
    property bool busy: false
    property string error: ""
    property string _output: ""
    readonly property string helper: Qt.resolvedUrl("../modules/island/removable-drives.py").toString().replace("file://", "")
    function accept(text, clearError) {
        try {
            const result = JSON.parse(text);
            if (!result.ok) { root.error = result.error || qsTr("Drive operation failed"); return; }
            if (Array.isArray(result.drives)) root.drives = result.drives;
            if (clearError) root.error = "";
        } catch (e) { root.error = qsTr("Could not read removable drives"); }
    }
    function run(action, path) {
        if (root.busy) return false;
        root.busy = true;
        root.error = "";
        root._output = "";
        operation.command = ["python3", root.helper, action].concat(path ? [path] : []);
        operation.running = true;
        return true;
    }
    function refresh() { return run("list", ""); }
    function mount(path) { return run("mount", path); }
    function unmount(path) { return run("unmount", path); }
    function eject(path) { return run("eject", path); }
    function open(path) { return run("open", path); }
    property Process watcher: Process {
        command: ["python3", root.helper, "watch"]
        running: true
        stdout: SplitParser { onRead: data => root.accept(data) }
        stderr: StdioCollector { id: watchError }
        onExited: (exitCode, exitStatus) => { if (exitCode !== 0) root.error = watchError.text.trim() || qsTr("Drive monitoring is unavailable"); }
    }
    property Process operation: Process {
        stdout: StdioCollector { onStreamFinished: root._output = text }
        stderr: StdioCollector { id: operationError }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (root._output.trim()) root.accept(root._output, true);
            else root.error = operationError.text.trim() || qsTr("Drive operation failed");
        }
    }
}
