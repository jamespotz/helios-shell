pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Free, no-API-key current-conditions lookup via wttr.in. With no override
// set it geolocates by the requester's IP; setLocation() pins it to a city
// name or "lat,long" instead, persisted in Quickshell's state directory.
QtObject {
    id: root

    property bool available: false
    property bool loading: false
    property real tempC: 0
    property real feelsLikeC: 0
    property string condition: ""
    property string location: ""
    property real minTempC: 0
    property real maxTempC: 0
    property int humidity: 0
    property real windKmph: 0
    property int uvIndex: 0
    property string sunrise: ""
    property string sunset: ""
    // Today's remaining forecast (wttr.in reports in 3-hour blocks):
    // [{ label: "15:00", tempC, condition, icon, chanceOfRain }, ...]
    property var hourly: []
    // Per-day summaries for the day-nav in WeatherPanel — index 0 is today
    // (mirrors the flat properties above, so day-nav offset 0 always matches
    // "current conditions" exactly), 1/2 are tomorrow/day-after built from
    // that day's midday (12:00) block, since wttr.in's free tier only ever
    // returns 3 days and has no single "current" reading for future days.
    // [{ date, tempC, feelsLikeC, condition, icon, humidity, windKmph,
    //    chanceOfRain, minTempC, maxTempC }, ...]
    property var daily: []

    readonly property string locationOverride: settingsAdapter.locationOverride

    // Shared by WeatherWidget (peek), IdleBump (idle) and WeatherPanel's
    // hourly strip so they all agree on which glyph a condition maps to.
    function iconFor(conditionText) {
        const c = (conditionText || "").toLowerCase();
        if (c.includes("thunder")) return "thunderstorm";
        if (c.includes("snow") || c.includes("sleet") || c.includes("ice")) return "ac_unit";
        if (c.includes("rain") || c.includes("drizzle")) return "rainy";
        if (c.includes("fog") || c.includes("mist") || c.includes("haze")) return "foggy";
        if (c.includes("cloud") || c.includes("overcast")) return "cloud";
        if (c.includes("sun") || c.includes("clear")) return "wb_sunny";
        return "cloud";
    }
    readonly property string icon: root.iconFor(root.condition)

    function setLocation(text) {
        settingsAdapter.locationOverride = text.trim();
        root.settingsFile.writeAdapter();
        root.refresh();
    }

    function refresh() {
        if (root.loading) return;
        root.loading = true;

        const override = settingsAdapter.locationOverride;
        const url = "https://wttr.in/" + (override ? encodeURIComponent(override) : "") + "?format=j1";

        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.loading = false;
            if (xhr.status !== 200) { root.available = false; return; }

            try {
                const data = JSON.parse(xhr.responseText);
                const current = data.current_condition[0];
                root.tempC = parseFloat(current.temp_C);
                root.feelsLikeC = parseFloat(current.FeelsLikeC);
                root.condition = current.weatherDesc[0].value;
                root.location = data.nearest_area && data.nearest_area[0]
                    ? data.nearest_area[0].areaName[0].value : "";
                root.humidity = parseInt(current.humidity, 10) || 0;
                root.windKmph = parseFloat(current.windspeedKmph) || 0;
                root.uvIndex = parseInt(current.uvIndex, 10) || 0;

                const today = data.weather && data.weather[0];
                if (today) {
                    root.minTempC = parseFloat(today.mintempC);
                    root.maxTempC = parseFloat(today.maxtempC);
                    const astro = today.astronomy && today.astronomy[0];
                    root.sunrise = astro ? astro.sunrise : "";
                    root.sunset = astro ? astro.sunset : "";

                    // "time" is the hour*100 as a string ("0", "300", ...,
                    // "2100") in 3-hour blocks, not literal minutes — only
                    // keep blocks still ahead of now so this reads as
                    // "coming up", not the whole day from midnight.
                    const nowHour = new Date().getHours();
                    const blocks = [];
                    for (const day of [data.weather[0], data.weather[1]]) {
                        if (!day || !day.hourly) continue;
                        for (const h of day.hourly) {
                            const hour = Math.floor(parseInt(h.time, 10) / 100);
                            if (day === data.weather[0] && hour < nowHour) continue;
                            const hh = String(hour).padStart(2, "0");
                            blocks.push({
                                label: hh + ":00",
                                tempC: parseFloat(h.tempC),
                                condition: h.weatherDesc[0].value,
                                icon: root.iconFor(h.weatherDesc[0].value),
                                chanceOfRain: parseInt(h.chanceofrain, 10) || 0
                            });
                            if (blocks.length >= 8) break;
                        }
                        if (blocks.length >= 8) break;
                    }
                    root.hourly = blocks;
                }

                const days = [];
                for (let i = 0; i < (data.weather ? data.weather.length : 0); i++) {
                    const day = data.weather[i];
                    if (!day) continue;

                    if (i === 0) {
                        // Today: reuse the real "right now" reading rather than
                        // a midday estimate, so day-nav offset 0 exactly matches
                        // the current-conditions display above it.
                        days.push({
                            date: day.date,
                            tempC: root.tempC,
                            feelsLikeC: root.feelsLikeC,
                            condition: root.condition,
                            icon: root.iconFor(root.condition),
                            humidity: root.humidity,
                            windKmph: root.windKmph,
                            chanceOfRain: root.hourly.length > 0 ? root.hourly[0].chanceOfRain : 0,
                            minTempC: parseFloat(day.mintempC),
                            maxTempC: parseFloat(day.maxtempC)
                        });
                        continue;
                    }

                    // Future day: no "current" reading exists, so fall back to
                    // the block closest to midday as a representative snapshot.
                    let midday = day.hourly && day.hourly[0];
                    for (const h of (day.hourly || [])) {
                        if (Math.abs(parseInt(h.time, 10) - 1200) < Math.abs(parseInt(midday.time, 10) - 1200)) {
                            midday = h;
                        }
                    }
                    if (!midday) continue;

                    days.push({
                        date: day.date,
                        tempC: parseFloat(midday.tempC),
                        feelsLikeC: parseFloat(midday.FeelsLikeC),
                        condition: midday.weatherDesc[0].value,
                        icon: root.iconFor(midday.weatherDesc[0].value),
                        humidity: parseInt(midday.humidity, 10) || 0,
                        windKmph: parseFloat(midday.windspeedKmph) || 0,
                        chanceOfRain: parseInt(midday.chanceofrain, 10) || 0,
                        minTempC: parseFloat(day.mintempC),
                        maxTempC: parseFloat(day.maxtempC)
                    });
                }
                root.daily = days;

                root.available = true;
            } catch (e) {
                root.available = false;
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("weather.json")
        watchChanges: true
        // Wait for the persisted location (if any) to load before the first
        // fetch, rather than fetching once with the default then again.
        onLoaded: root.refresh()
        onLoadFailed: root.refresh()

        JsonAdapter {
            id: settingsAdapter
            property string locationOverride: ""
        }
    }

    property Timer refreshTimer: Timer {
        interval: 20 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
