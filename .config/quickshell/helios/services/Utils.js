.pragma library

function screenForMonitor(screens, monitor) {
    if (!monitor)
        return null;
    for (let i = 0; i < screens.length; i++) {
        if (screens[i].name === monitor.name)
            return screens[i];
    }
    return null;
}

function focusedScreen(screens, monitor) {
    return screenForMonitor(screens, monitor) || screens[0];
}
