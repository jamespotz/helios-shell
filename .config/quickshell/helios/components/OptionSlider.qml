import QtQuick

// SettingsSlider bound to a numeric option on `target` (see OptionToggle);
// the range comes from target.range(option).
SettingsSlider {
    id: root
    property var target
    property string option: ""

    value: root.target[root.option]
    from: root.target.range(root.option)[0]
    to: root.target.range(root.option)[1]
    onMoved: v => root.target.setOption(root.option, v)
}
