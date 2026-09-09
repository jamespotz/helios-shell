import QtQuick
import Quickshell.Services.Polkit

// Registers this shell as the system's PolicyKit1 authentication agent —
// no external polkit-kde-agent/hyprpolkitagent binary needed, and (unlike
// a compositor-bundled agent) this works under any Wayland compositor that
// supports wlr-layer-shell, since that's all Quickshell itself needs.
// PolkitAgent registers itself with the polkit daemon the moment it's
// instantiated; isActive flips true for the duration of one auth request.
Item {
    id: root

    PolkitAgent {
        id: agent
    }

    Loader {
        active: agent.isActive
        sourceComponent: PolkitPrompt { flow: agent.flow }
    }
}
