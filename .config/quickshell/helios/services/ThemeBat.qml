pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// bat
QtObject {
    id: root

    function buildBatTheme(p) {
        const rule = (name, scope, color, style) => "        <dict>\n"
            + "            <key>name</key><string>" + name + "</string>\n"
            + "            <key>scope</key><string>" + scope + "</string>\n"
            + "            <key>settings</key><dict>\n"
            + "                <key>foreground</key><string>" + color + "</string>\n"
            + (style ? "                <key>fontStyle</key><string>" + style + "</string>\n" : "")
            + "            </dict>\n"
            + "        </dict>\n";
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            + "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
            + "<plist version=\"1.0\">\n<dict>\n"
            + "    <key>name</key><string>Helios</string>\n"
            + "    <key>settings</key>\n    <array>\n"
            + "        <dict>\n            <key>settings</key>\n            <dict>\n"
            + "                <key>background</key><string>" + p.background + "</string>\n"
            + "                <key>foreground</key><string>" + p.text + "</string>\n"
            + "                <key>caret</key><string>" + p.accent + "</string>\n"
            + "                <key>selection</key><string>" + p.surfaceHigh + "</string>\n"
            + "                <key>lineHighlight</key><string>" + p.surface + "</string>\n"
            + "                <key>invisibles</key><string>" + p.overlay + "</string>\n"
            + "            </dict>\n        </dict>\n"
            + rule("Comment", "comment", p.subtext, "italic")
            + rule("String", "string", p.success, null)
            + rule("Number", "constant.numeric", p.warning, null)
            + rule("Keyword", "keyword", p.danger, null)
            + rule("Storage/Type", "storage, storage.type", p.accent, null)
            + rule("Function", "entity.name.function, support.function", p.accent, null)
            + rule("Variable", "variable", p.text, null)
            + rule("Constant", "constant.language, constant.other", p.warning, null)
            + "    </array>\n"
            + "    <key>uuid</key><string>b8a1c2d3-e4f5-4a6b-9c8d-0e1f2a3b4c5d</string>\n"
            + "</dict>\n</plist>\n";
    }

    function writeBatTheme(p) {
        const home = Quickshell.env("HOME");
        batThemeFile.path = home + "/.config/bat/themes/Helios.tmTheme";
        batThemeFile.setText(root.buildBatTheme(p));

        batConfigFile.path = home + "/.config/bat/config";
        const existing = batConfigFile.text();
        const stripped = existing.split("\n").filter(l => !/^\s*--theme=/.test(l)).join("\n").replace(/\s*$/, "");
        batConfigFile.setText((stripped.length > 0 ? stripped + "\n" : "") + "--theme=\"Helios\"\n");

        batCacheProc.running = false;
        batCacheProc.running = true;
    }

    property FileView batThemeFile: FileView { printErrors: false; atomicWrites: true }
    property FileView batConfigFile: FileView { printErrors: false; atomicWrites: true; preload: true; blockLoading: true }
    property Process batCacheProc: Process { command: ["bat", "cache", "--build"] }
}
