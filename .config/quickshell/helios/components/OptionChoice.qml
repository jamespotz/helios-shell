import QtQuick

// SettingsRow with a SegmentedControl bound to a choice option on `target`
// (see OptionToggle). choices entries: { value, label }.
SettingsRow {
    id: root
    property var target
    property string option: ""
    property var choices: []

    SegmentedControl {
        implicitHeight: 32
        model: root.choices
        currentValue: root.target[root.option]
        onActivated: v => root.target.setOption(root.option, v)
    }
}
