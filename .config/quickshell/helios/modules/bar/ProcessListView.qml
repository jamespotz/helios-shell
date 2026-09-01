import QtQuick
import Quickshell
import "../../services"
import "../../components"

Item {
    id: root
    signal backRequested()

    property string searchText: ""
    property string filterMode: "all"
    property string sortColumn: "cpu_percent"
    property int sortDir: -1
    readonly property string currentUser: Quickshell.env("USER")
    readonly property int actionsWidth: 108

    function isProtected(p) {
        const name = p.name.toLowerCase();
        return p.pid === 1 || name.indexOf("quickshell") !== -1 || name.indexOf("hyprland") !== -1;
    }
    function matchesMode(p) {
        if (filterMode === "apps") return p.user === currentUser && p.cmdline.charAt(0) !== "[";
        if (filterMode === "system") return p.user === "root";
        if (filterMode === "background") return p.cpu_percent < 0.1;
        return true;
    }
    function toggleSort(column) {
        if (sortColumn === column) sortDir = -sortDir;
        else {
            sortColumn = column;
            sortDir = column === "pid" || column === "name" ? 1 : -1;
        }
    }
    function memoryText(p) {
        const mib = (SystemStats.state.memory.total_gb || 0) * 1024 * p.memory_percent / 100;
        return mib >= 1024 ? (mib / 1024).toFixed(1) + " GB" : mib.toFixed(mib < 10 ? 1 : 0) + " MB";
    }

    readonly property var processedList: {
        const query = searchText.trim().toLowerCase();
        let list = SystemStats.state.processes.filter(p => matchesMode(p) && (query.length === 0
            || p.name.toLowerCase().indexOf(query) !== -1
            || (p.cmdline || "").toLowerCase().indexOf(query) !== -1
            || String(p.pid).indexOf(query) !== -1));
        const column = sortColumn;
        const direction = sortDir;
        return list.slice().sort((a, b) => {
            const av = a[column], bv = b[column];
            return typeof av === "string"
                ? direction * av.toLowerCase().localeCompare(bv.toLowerCase())
                : direction * (av - bv);
        });
    }

    implicitWidth: 620
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width

        Item {
            width: parent.width; height: 58
            IconButton {
                id: backButton
                anchors.left: parent.left; anchors.top: parent.top
                icon: "arrow_back"
                onClicked: root.backRequested()
            }
            Column {
                anchors.left: backButton.right; anchors.leftMargin: 10; anchors.top: parent.top
                spacing: 4
                StyledText { text: "Process Explorer"; font.bold: true; font.pixelSize: Config.fontSize + 5 }
                StyledText {
                    text: SystemStats.state.processes.length + " processes  ·  "
                        + SystemStats.state.cpu.usage_percent.toFixed(1) + "% CPU  ·  "
                        + SystemStats.state.memory.used_gb.toFixed(1) + " GB in use"
                    color: Colors.subtext; font.pixelSize: Config.fontSize - 2
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.top: parent.top
                width: 62; height: 28; radius: Colors.radiusSmall; color: Colors.surfaceHigh
                Row {
                    anchors.centerIn: parent; spacing: 7
                    Rectangle { width: 7; height: 7; radius: 4; color: Colors.success; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Live"; color: Colors.subtext; font.pixelSize: Config.fontSize - 3 }
                }
            }
        }

        Item {
            width: parent.width; height: 48
            SearchField {
                id: search
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: 270; height: 36; inputPixelSize: Config.fontSize - 2
                placeholder: "Filter by name, PID, or command"
                onTextChanged: root.searchText = text
            }
            SegmentedControl {
                anchors.left: search.right; anchors.leftMargin: 10; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter; height: 36
                currentValue: root.filterMode
                model: [
                    { value: "all", label: "All" }, { value: "apps", label: "Apps" },
                    { value: "system", label: "System" }, { value: "background", label: "Background" }
                ]
                onActivated: value => root.filterMode = value
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.outline; opacity: 0.65 }
        Item {
            width: parent.width; height: 32
            SortHeader { anchors.left: parent.left; anchors.leftMargin: 8; width: 46; label: "PID"; column: "pid" }
            SortHeader { anchors.left: parent.left; anchors.leftMargin: 62; width: 90; label: "Program"; column: "name" }
            SortHeader { anchors.left: parent.left; anchors.leftMargin: 160; anchors.right: memHeader.left; anchors.rightMargin: 10; label: "Command"; column: "cmdline" }
            SortHeader { id: memHeader; anchors.right: cpuHeader.left; anchors.rightMargin: 10; width: 62; label: "Memory"; column: "memory_percent"; alignRight: true }
            SortHeader { id: cpuHeader; anchors.right: parent.right; anchors.rightMargin: root.actionsWidth + 8; width: 72; label: "CPU"; column: "cpu_percent"; alignRight: true }
        }

        Item {
            width: parent.width
            height: root.processedList.length === 0 ? 76 : Math.min(378, root.processedList.length * 42)
            StyledText {
                anchors.centerIn: parent; visible: root.processedList.length === 0
                text: SystemStats.state.processes.length === 0 ? "Loading processes…" : "No matching processes"
                color: Colors.subtext
            }
            ListView {
                id: listView
                anchors.fill: parent; visible: root.processedList.length > 0
                clip: true; model: root.processedList; boundsBehavior: Flickable.StopAtBounds
                delegate: ProcessRow {
                    width: listView.width
                    required property var modelData
                    processData: modelData
                    protected_: root.isProtected(modelData)
                }
            }
            ScrollIndicator { target: listView }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.outline; opacity: 0.65 }
        Item {
            width: parent.width; height: 30
            StyledText {
                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: root.processedList.length + " shown  ·  " + SystemStats.state.processes.length + " running"
                color: Colors.subtext; font.pixelSize: Config.fontSize - 3
            }
            StyledText {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: "Updated every 5s"; color: Colors.subtext; font.pixelSize: Config.fontSize - 3
            }
        }
    }

    component SortHeader: Item {
        id: header
        property string label
        property string column
        property bool alignRight: false
        height: 32
        Row {
            anchors.right: header.alignRight ? parent.right : undefined
            anchors.left: header.alignRight ? undefined : parent.left
            anchors.verticalCenter: parent.verticalCenter; spacing: 2
            MaterialIcon {
                visible: root.sortColumn === header.column
                icon: root.sortDir === 1 ? "keyboard_arrow_up" : "keyboard_arrow_down"
                font.pixelSize: 13; color: Colors.subtext
            }
            StyledText {
                text: header.label
                color: root.sortColumn === header.column ? Colors.text : Colors.subtext
                font.bold: true; font.pixelSize: Config.fontSize - 3
            }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleSort(header.column)
        }
    }

    component ProcessRow: Item {
        id: row
        required property var processData
        required property bool protected_
        property string armedAction: ""
        property string errorText: ""
        height: 42

        Timer { id: armTimer; interval: 3000; onTriggered: row.armedAction = "" }
        Timer { id: errorTimer; interval: 2500; onTriggered: row.errorText = "" }
        Connections {
            target: SystemStats
            function onProcessKillResult(pid, success, message) {
                if (pid !== row.processData.pid || success) return;
                row.errorText = message.length > 0 ? message : "Failed";
                errorTimer.restart();
            }
        }
        function act(action) {
            if (protected_) { errorText = "Protected process"; errorTimer.restart(); return; }
            if (armedAction === action) {
                armedAction = "";
                SystemStats.actOnProcess(processData.pid, action === "term" ? "terminate" : "forceStop");
            } else { armedAction = action; armTimer.restart(); }
        }

        Rectangle {
            anchors.fill: parent
            color: row.errorText.length || row.armedAction.length ? Colors.danger : rowHover.hovered ? Colors.surfaceHigh : "transparent"
            opacity: row.errorText.length ? 0.18 : row.armedAction.length ? 0.13 : rowHover.hovered ? 0.45 : 1
            Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
        }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Colors.outline; opacity: 0.45 }
        HoverHandler { id: rowHover }

        StyledText {
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
            width: 46; text: String(row.processData.pid); color: Colors.subtext
            font.family: Config.monoFontFamily; font.pixelSize: Config.fontSize - 3
        }
        StyledText {
            anchors.left: parent.left; anchors.leftMargin: 62; anchors.verticalCenter: parent.verticalCenter
            width: 90; elide: Text.ElideRight
            text: row.errorText.length ? row.errorText : row.processData.name
            color: row.errorText.length ? Colors.danger : Colors.text
            font.weight: Font.DemiBold; font.pixelSize: Config.fontSize - 2
        }
        StyledText {
            anchors.left: parent.left; anchors.leftMargin: 160
            anchors.right: memoryLabel.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight; text: row.processData.cmdline; color: Colors.subtext
            font.family: Config.monoFontFamily; font.pixelSize: Config.fontSize - 3
        }
        StyledText {
            id: memoryLabel
            anchors.right: cpuCell.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 62; horizontalAlignment: Text.AlignRight; text: root.memoryText(row.processData)
            font.pixelSize: Config.fontSize - 3
        }
        Item {
            id: cpuCell
            anchors.right: actions.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 72; height: 20
            Rectangle {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 4; radius: 2; color: Colors.surfaceHigh
                Rectangle {
                    width: Math.min(parent.width, parent.width * row.processData.cpu_percent / 100)
                    height: parent.height; radius: parent.radius; color: Colors.accent
                    Behavior on width { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                }
            }
            StyledText {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: row.processData.cpu_percent.toFixed(1) + "%"
                font.family: Config.monoFontFamily; font.pixelSize: Config.fontSize - 3
            }
        }
        Row {
            id: actions
            anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            PrimaryButton {
                width: 50; height: 28; text: row.armedAction === "term" ? "Sure?" : "End"
                active: row.armedAction === "term"; tint: Colors.accent
                onClicked: row.act("term")
            }
            PrimaryButton {
                width: 50; height: 28; text: row.armedAction === "kill" ? "Sure?" : "Kill"
                active: row.armedAction === "kill"; tint: Colors.danger
                onClicked: row.act("kill")
            }
        }
    }
}
