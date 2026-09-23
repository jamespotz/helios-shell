import QtQuick

QtObject {
    function layoutForWorkspace(response, workspaceId) {
        try {
            const workspaces = JSON.parse(response);
            const workspace = workspaces.find(item => item.id === workspaceId);
            return workspace && typeof workspace.tiledLayout === "string" ? workspace.tiledLayout : "";
        } catch (error) {
            return "";
        }
    }

    function iconForLayout(layout) {
        switch (layout) {
        case "scrolling": return "width_wide";
        case "dwindle": return "grid_view";
        case "master": return "view_quilt";
        case "monocle": return "circles";
        default: return "dashboard";
        }
    }
}
