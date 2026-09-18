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

function formatPercent(value) {
    return value.toFixed(1) + "%";
}

function formatGB(valueMb) {
    return (valueMb / 1024).toFixed(1) + " GB";
}

function formatValueGB(valueGb) {
    return valueGb.toFixed(1) + " GB";
}

function formatGHz(valueMhz) {
    return ((valueMhz || 0) / 1000).toFixed(2) + " GHz";
}

function formatBytesPerSec(bytesPerSec) {
    if (bytesPerSec < 1024) return bytesPerSec.toFixed(0) + " B/s";
    if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(0) + " K/s";
    return (bytesPerSec / (1024 * 1024)).toFixed(1) + " M/s";
}
