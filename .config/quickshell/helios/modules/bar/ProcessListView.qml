import QtQuick
import "../../services"
import "../../components"

// Full sortable/filterable process table for the System tab's "View All"
// link — swapped in place of the dashboard by SystemMonitorTab.qml rather
// than living as its own tab. Backed by SystemStats.state.processes, which
// SystemMonitorTab switches into "full" mode (all processes, capped at
// 1000, with cmdline/user) for as long as this view stays visible.
Item {
    id: root

    signal backRequested()

    // A pid or process name this shell can't afford to lose. Checked before
    // a row is even allowed to arm — Terminate/Kill stay visible but refuse
    // to do anything for these, rather than letting a fat-fingered double
    // click take down the compositor or the shell itself.
    function isProtected(modelData) {
        if (modelData.pid === 1) return true;
        const n = modelData.name.toLowerCase();
        return n.indexOf("quickshell") !== -1 || n.indexOf("hyprland") !== -1;
    }

    property string searchText: ""
    property string sortColumn: "cpu_percent"
    property int sortDir: -1 // -1 descending, 1 ascending

    // Shared with ProcessRow's actionsRow so the CPU/Mem column headers stay
    // aligned with the actual data cells regardless of button sizing.
    readonly property int actionButtonWidth: 64
    readonly property int actionsRowWidth: actionButtonWidth * 2 + 4

    function toggleSort(column) {
        if (root.sortColumn === column) {
            root.sortDir = -root.sortDir;
        } else {
            root.sortColumn = column;
            root.sortDir = (column === "pid" || column === "name") ? 1 : -1;
        }
    }

    readonly property var processedList: {
        const q = root.searchText.trim().toLowerCase();
        let list = SystemStats.state.processes;
        if (q.length > 0) {
            list = list.filter(p =>
                p.name.toLowerCase().indexOf(q) !== -1 ||
                (p.cmdline || "").toLowerCase().indexOf(q) !== -1 ||
                String(p.pid).indexOf(q) !== -1
            );
        }
        const col = root.sortColumn;
        const dir = root.sortDir;
        return list.slice().sort((a, b) => {
            let av = a[col], bv = b[col];
            if (typeof av === "string") return dir * av.toLowerCase().localeCompare(bv.toLowerCase());
            return dir * (av - bv);
        });
    }

    implicitWidth: 620
    implicitHeight: outerCol.implicitHeight

    Column {
        id: outerCol
        width: parent.width
        spacing: 12

        // --- Header: back + title + count -----------------------------------
        Item {
            width: parent.width
            height: 28

            IconButton {
                id: backBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: "arrow_back"
                onClicked: root.backRequested()
            }

            StyledText {
                anchors.left: backBtn.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "All Processes"
                font.bold: true
                font.pixelSize: Config.fontSize - 1
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.processedList.length + " / " + SystemStats.state.processes.length
                opacity: 0.5
                font.pixelSize: Config.fontSize - 3
                font.family: Config.monoFontFamily
            }
        }

        SearchField {
            id: search
            width: parent.width
            placeholder: "Filter by name, command, or PID…"
            onTextChanged: root.searchText = text
        }

        // --- Column headers ---------------------------------------------------
        Item {
            width: parent.width
            height: 22

            SortHeaderLabel { anchors.left: parent.left; anchors.leftMargin: 8; width: 44; label: "PID"; column: "pid" }
            SortHeaderLabel { anchors.left: parent.left; anchors.leftMargin: 56; width: 100; label: "Program"; column: "name" }
            SortHeaderLabel { anchors.right: cpuHeader.left; anchors.rightMargin: 8; anchors.left: parent.left; anchors.leftMargin: 160; label: "Command"; column: "cmdline" }
            SortHeaderLabel { id: cpuHeader; anchors.right: memHeader.left; anchors.rightMargin: 8; width: 50; label: "CPU"; column: "cpu_percent"; alignRight: true }
            SortHeaderLabel { id: memHeader; anchors.right: parent.right; anchors.rightMargin: 16 + root.actionsRowWidth; width: 50; label: "Mem"; column: "memory_percent"; alignRight: true }
        }

        StyledText {
            visible: root.processedList.length === 0
            text: SystemStats.state.processes.length === 0 ? "Loading processes…" : "No matching processes"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // Wraps the ListView so ScrollIndicator — which anchors to its
        // target's edges — is a sibling of the Flickable rather than a
        // child inside it (see components/ScrollIndicator.qml).
        Item {
            id: listWrap
            width: parent.width
            visible: root.processedList.length > 0
            height: Math.min(360, root.processedList.length * 34)

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: 1
                model: root.processedList
                boundsBehavior: Flickable.StopAtBounds

                delegate: ProcessRow {
                    width: listView.width
                    required property var modelData
                    processData: modelData
                    protected_: root.isProtected(modelData)
                }
            }

            ScrollIndicator { target: listView }
        }
    }

    component SortHeaderLabel: Item {
        id: headerLabel
        property string label: ""
        property string column: ""
        property bool alignRight: false
        height: 22

        StyledText {
            id: labelText
            anchors.right: headerLabel.alignRight ? parent.right : undefined
            anchors.left: headerLabel.alignRight ? undefined : parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: headerLabel.label
            opacity: 0.5
            font.bold: true
            font.pixelSize: Config.fontSize - 3
            color: root.sortColumn === headerLabel.column ? Colors.accent : Colors.text
        }

        MaterialIcon {
            visible: root.sortColumn === headerLabel.column
            anchors.right: headerLabel.alignRight ? labelText.left : undefined
            anchors.left: headerLabel.alignRight ? undefined : labelText.right
            anchors.rightMargin: 2
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            icon: root.sortDir === 1 ? "arrow_upward" : "arrow_downward"
            font.pixelSize: 11
            color: Colors.accent
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleSort(headerLabel.column)
        }
    }

    component ProcessRow: Item {
        id: row
        required property var processData
        required property bool protected_
        height: 32

        property string armedAction: ""
        property string errorText: ""

        Timer { id: armTimer; interval: 3000; onTriggered: row.armedAction = "" }
        Timer { id: errorTimer; interval: 2500; onTriggered: row.errorText = "" }

        Connections {
            target: SystemStats
            function onProcessKillResult(pid, success, message) {
                if (pid !== row.processData.pid) return;
                if (!success) {
                    row.errorText = message.length > 0 ? message : "Failed";
                    errorTimer.restart();
                }
            }
        }

        function pressTerm() {
            if (row.protected_) { row.errorText = "Protected process"; errorTimer.restart(); return; }
            if (row.armedAction === "term") { row.armedAction = ""; SystemStats.actOnProcess(row.processData.pid, "terminate"); }
            else { row.armedAction = "term"; armTimer.restart(); }
        }
        function pressKill() {
            if (row.protected_) { row.errorText = "Protected process"; errorTimer.restart(); return; }
            if (row.armedAction === "kill") { row.armedAction = ""; SystemStats.actOnProcess(row.processData.pid, "forceStop"); }
            else { row.armedAction = "kill"; armTimer.restart(); }
        }

        Rectangle {
            anchors.fill: parent
            radius: Colors.radiusSmall
            color: (row.errorText.length > 0 || row.armedAction.length > 0) ? Colors.danger : Colors.surfaceHigh
            opacity: row.errorText.length > 0 ? 0.25 : (row.armedAction.length > 0 ? 0.18 : (rowHover.hovered ? 0.5 : 0))
            Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
        }

        HoverHandler { id: rowHover }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            text: String(row.processData.pid)
            opacity: 0.6
            font.family: Config.monoFontFamily
            font.pixelSize: Config.fontSize - 3
        }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 56
            anchors.verticalCenter: parent.verticalCenter
            width: 100
            elide: Text.ElideRight
            text: row.errorText.length > 0 ? row.errorText : row.processData.name
            color: row.errorText.length > 0 ? Colors.danger : Colors.text
            font.pixelSize: Config.fontSize - 2
        }

        StyledText {
            id: cmdText
            anchors.left: parent.left
            anchors.leftMargin: 160
            anchors.right: cpuText.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            opacity: 0.6
            text: row.processData.cmdline
            font.pixelSize: Config.fontSize - 3
            font.family: Config.monoFontFamily

            HoverHandler { id: cmdHover }

            Rectangle {
                visible: cmdHover.hovered && cmdText.truncated
                anchors.bottom: parent.top
                anchors.bottomMargin: 4
                anchors.left: parent.left
                width: tooltipText.implicitWidth + 16
                height: tooltipText.implicitHeight + 10
                radius: Colors.radiusSmall
                color: Colors.surfaceHigh
                z: 10

                StyledText {
                    id: tooltipText
                    anchors.centerIn: parent
                    text: row.processData.cmdline
                    font.family: Config.monoFontFamily
                    font.pixelSize: Config.fontSize - 3
                }
            }
        }

        StyledText {
            id: cpuText
            anchors.right: memText.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            horizontalAlignment: Text.AlignRight
            text: row.processData.cpu_percent.toFixed(1) + "%"
            font.family: Config.monoFontFamily
            font.pixelSize: Config.fontSize - 2
        }

        StyledText {
            id: memText
            anchors.right: actionsRow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            horizontalAlignment: Text.AlignRight
            opacity: 0.6
            text: row.processData.memory_percent.toFixed(1) + "%"
            font.family: Config.monoFontFamily
            font.pixelSize: Config.fontSize - 3
        }

        Row {
            id: actionsRow
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            // Fixed-width buttons (label swaps to "Confirm?" rather than
            // resizing) so hover/arm state never shifts the column layout.
            opacity: (rowHover.hovered || row.armedAction.length > 0) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

            PrimaryButton {
                width: root.actionButtonWidth
                height: 24
                icon: row.armedAction === "term" ? "" : "stop_circle"
                text: row.armedAction === "term" ? "Confirm?" : "End"
                active: row.armedAction === "term"
                tint: Colors.accent
                onClicked: row.pressTerm()
            }
            PrimaryButton {
                width: root.actionButtonWidth
                height: 24
                icon: row.armedAction === "kill" ? "" : "cancel"
                text: row.armedAction === "kill" ? "Confirm?" : "Kill"
                active: row.armedAction === "kill"
                tint: Colors.danger
                onClicked: row.pressKill()
            }
        }
    }
}
