import QtQuick

QtObject {
    property string preferredName: ""
    property var knownNames: []
    property bool synced: false
    property var startupNames: []
    function update(names, ready) {
        if (!ready || !synced) {
            seed(names);
            startupNames = names.slice();
            synced = ready;
            return "";
        }
        startupNames = startupNames.filter(name => names.includes(name));
        return arrived(names);
    }
    function canRouteConnection(name, ready) {
        return !preferredName || (ready && name === preferredName && !startupNames.includes(name));
    }
    function seed(names) { knownNames = names.slice(); }
    function arrived(names) {
        const added = names.filter(name => !knownNames.includes(name));
        knownNames = names.slice();
        return preferredName && added.includes(preferredName) ? preferredName : "";
    }
    function prefer(name, names) {
        preferredName = name;
        seed(names);
        return name && names.includes(name) ? name : "";
    }
}
