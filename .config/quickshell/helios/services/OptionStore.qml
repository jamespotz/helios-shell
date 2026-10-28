import QtQuick
import Quickshell
import Quickshell.Io

// The user options of one settings file: checks and clamps values against
// a schema, debounces saving, resets, and copies/pastes presets through the
// clipboard. Each option is `{ value, range?, step?, choices? }`: a default,
// plus [min, max] (and step) for numbers or the allowed values for choices.
// The owner holds the values as properties on `target` and writes its file
// on saveRequested.
QtObject {
    id: root

    required property var options
    required property QtObject target
    // Preset envelope name ("island", "dock") and what the status note calls it.
    property string presetName: ""
    property string presetLabel: ""
    property var presetKeys: Object.keys(root.options)
    // Optional function(options) that upgrades an older preset's options in place.
    property var migratePreset: null

    signal saveRequested()

    function range(key) { return root.options[key].range; }

    // Returns the stored value: clamped and stepped for numbers, undefined
    // for an unknown key, an unknown choice, or a wrongly-typed value.
    function coerce(key, value) {
        const option = root.options[key];
        if (!option || typeof value !== typeof option.value) return undefined;
        if (Array.isArray(option.value) !== Array.isArray(value)) return undefined;
        if (option.choices) return option.choices.includes(value) ? value : undefined;
        if (!option.range) return value;
        const step = option.step || 1;
        const clamped = Math.max(option.range[0], Math.min(option.range[1], value));
        return Number((Math.round(clamped / step) * step).toFixed(4));
    }

    // Applies immediately; the file write is debounced so dragging a
    // slider doesn't rewrite the file every frame.
    function set(key, value) {
        const coerced = root.coerce(key, value);
        if (coerced === undefined) return false;
        root.target[key] = coerced;
        root.save();
        return true;
    }

    // Sets each of `keys` found in `values`; invalid ones are skipped.
    // Returns how many were set. Doesn't save.
    function apply(values, keys) {
        let applied = 0;
        for (const key of keys || Object.keys(root.options)) {
            if (!values || !(key in values)) continue;
            const coerced = root.coerce(key, values[key]);
            if (coerced === undefined) continue;
            root.target[key] = coerced;
            applied++;
        }
        return applied;
    }

    // Puts every invalid stored value (a hand edit) back to its default.
    function sanitize() {
        for (const key in root.options) {
            if (root.coerce(key, root.target[key]) === undefined) root.target[key] = root.options[key].value;
        }
    }

    function reset(keys) {
        for (const key of keys || Object.keys(root.options)) root.target[key] = root.options[key].value;
        root.save();
    }

    function save() { root._saveTimer.restart(); }

    property Timer _saveTimer: Timer { interval: 300; onTriggered: root.saveRequested() }

    function presetText() {
        const options = {};
        for (const key of root.presetKeys) options[key] = root.target[key];
        return JSON.stringify({ helios: root.presetName, version: 1, options: options }, null, 2);
    }

    // Returns how many settings were applied, or -1 when the text isn't
    // this kind of preset. Unknown keys and invalid values are skipped.
    function applyPreset(text) {
        let preset;
        try { preset = JSON.parse(text); } catch (e) { return -1; }
        if (!preset || preset.helios !== root.presetName || preset.version !== 1 || !preset.options
                || typeof preset.options !== "object" || Array.isArray(preset.options)) return -1;
        if (root.migratePreset) root.migratePreset(preset.options);
        const applied = root.apply(preset.options, root.presetKeys);
        root.save();
        return applied;
    }

    // Short result note after a copy or paste; clears itself.
    property string presetStatus: ""
    onPresetStatusChanged: if (root.presetStatus) root._presetStatusClear.restart()
    property Timer _presetStatusClear: Timer { interval: 4000; onTriggered: root.presetStatus = "" }

    function copyPreset() {
        Clipboard.copyText(root.presetText());
        root.presetStatus = "Copied " + root.presetLabel + " settings";
    }

    function pastePreset() { root._presetPaste.running = true; }

    property Process _presetPaste: Process {
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                const applied = root.applyPreset(this.text);
                root.presetStatus = applied < 0 ? "Clipboard doesn't hold " + root.presetLabel + " settings"
                    : "Applied " + applied + " settings";
            }
        }
    }
}
