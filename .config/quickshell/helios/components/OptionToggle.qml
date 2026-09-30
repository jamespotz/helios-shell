import QtQuick

// SettingsRow with a Toggle bound to a boolean option on `target` — a
// service exposing the option as a property plus setOption(key, value)
// (Config, Dock).
SettingsRow {
    id: root
    property var target
    property string option: ""

    Toggle {
        label: root.label
        checked: root.target[root.option]
        onToggled: v => root.target.setOption(root.option, v)
    }
}
