pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Free, no-API-key current-conditions lookup via Open-Meteo. With no
// override set it geolocates via ipapi.co; setLocation() pins it to a city
// name (geocoded via Open-Meteo's geocoding API) or "lat,long" instead,
// persisted in Quickshell's state directory.
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
    // Today's remaining forecast, next 8 hours: [{ label, tempC, condition,
    // icon, chanceOfRain }, ...]
    property var hourly: []
    // Per-day summaries for the day-nav in WeatherPanel — index 0 is today
    // (mirrors the flat properties above), 1/2 are tomorrow/day-after built
    // from that day's daily max/min + midday hourly block.
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

    // WMO weather-code -> human condition text (Open-Meteo returns a numeric
    // code, not a description). Kept as plain keyworded text so iconFor()
    // above needs no changes.
    function conditionFor(code) {
        const map = {
            0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Fog", 48: "Depositing rime fog",
            51: "Light drizzle", 53: "Drizzle", 55: "Dense drizzle",
            56: "Freezing drizzle", 57: "Dense freezing drizzle",
            61: "Slight rain", 63: "Rain", 65: "Heavy rain",
            66: "Freezing rain", 67: "Heavy freezing rain",
            71: "Slight snow fall", 73: "Snow fall", 75: "Heavy snow fall", 77: "Snow grains",
            80: "Slight rain showers", 81: "Rain showers", 82: "Violent rain showers",
            85: "Slight snow showers", 86: "Heavy snow showers",
            95: "Thunderstorm", 96: "Thunderstorm with hail", 99: "Thunderstorm with heavy hail"
        };
        return map[code] || "Cloudy";
    }

    function setLocation(text) {
        settingsAdapter.locationOverride = text.trim();
        root.settingsFile.writeAdapter();
        root.refresh();
    }

    function refresh() {
        if (root.loading) return;
        root.loading = true;

        const override = settingsAdapter.locationOverride;
        if (!override) {
            root._geolocate();
            return;
        }

        const m = override.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/);
        if (m) {
            root.location = override;
            root._fetchForecast(parseFloat(m[1]), parseFloat(m[2]));
        } else {
            root._geocode(override);
        }
    }

    // A cold start (shell/network just came up) can hit a geolocation/
    // geocoding/forecast request before DNS or the network is fully ready,
    // or a provider can blip — with no retry, that single failure used to
    // stick until the next scheduled refresh 20 minutes later, so the
    // widget could go dark for most of that window over a purely transient
    // hiccup. A few short, bounded retries smooth that over without
    // hammering the API if something's genuinely down.
    property int _retryCount: 0
    property Timer retryTimer: Timer {
        interval: 15000
        repeat: false
        onTriggered: root.refresh()
    }
    function _scheduleRetry() {
        if (root._retryCount >= 3) { root._retryCount = 0; return; }
        root._retryCount++;
        root.retryTimer.restart();
    }

    // No override set — resolve the requester's IP to a lat/long.
    function _geolocate() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { root.loading = false; root.available = false; root._scheduleRetry(); return; }
            try {
                const ip = JSON.parse(xhr.responseText);
                root.location = ip.city || "";
                root._fetchForecast(ip.latitude, ip.longitude);
            } catch (e) {
                root.loading = false;
                root.available = false;
                root._scheduleRetry();
            }
        };
        xhr.open("GET", "https://ipapi.co/json/");
        xhr.send();
    }

    // City-name override — resolve to a lat/long via Open-Meteo's own
    // geocoding endpoint.
    function _geocode(text) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { root.loading = false; root.available = false; root._scheduleRetry(); return; }
            try {
                const data = JSON.parse(xhr.responseText);
                const first = data.results && data.results[0];
                if (!first) { root.loading = false; root.available = false; return; }
                root.location = first.name;
                root._fetchForecast(first.latitude, first.longitude);
            } catch (e) {
                root.loading = false;
                root.available = false;
                root._scheduleRetry();
            }
        };
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(text));
        xhr.send();
    }

    function _fetchForecast(lat, lon) {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code,precipitation_probability"
            + "&daily=temperature_2m_max,temperature_2m_min,weather_code,uv_index_max,sunrise,sunset"
            + "&timezone=auto&forecast_days=3";

        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.loading = false;
            if (xhr.status !== 200) { root.available = false; root._scheduleRetry(); return; }

            try {
                const data = JSON.parse(xhr.responseText);
                const cur = data.current;
                root.tempC = cur.temperature_2m;
                root.feelsLikeC = cur.apparent_temperature;
                root.condition = root.conditionFor(cur.weather_code);
                root.humidity = Math.round(cur.relative_humidity_2m);
                root.windKmph = cur.wind_speed_10m;

                const daily = data.daily;
                if (daily && daily.time && daily.time.length > 0) {
                    root.minTempC = daily.temperature_2m_min[0];
                    root.maxTempC = daily.temperature_2m_max[0];
                    root.uvIndex = Math.round(daily.uv_index_max ? daily.uv_index_max[0] : 0);
                    root.sunrise = (daily.sunrise && daily.sunrise[0]) ? daily.sunrise[0].split("T")[1] : "";
                    root.sunset = (daily.sunset && daily.sunset[0]) ? daily.sunset[0].split("T")[1] : "";
                }

                // Next 8 hours, starting from now.
                const hourly = data.hourly;
                const blocks = [];
                if (hourly && hourly.time) {
                    const nowMs = Date.now();
                    for (let i = 0; i < hourly.time.length && blocks.length < 8; i++) {
                        if (new Date(hourly.time[i]).getTime() < nowMs) continue;
                        const hh = hourly.time[i].split("T")[1].slice(0, 5);
                        blocks.push({
                            label: hh,
                            tempC: hourly.temperature_2m[i],
                            condition: root.conditionFor(hourly.weather_code[i]),
                            icon: root.iconFor(root.conditionFor(hourly.weather_code[i])),
                            chanceOfRain: hourly.precipitation_probability ? hourly.precipitation_probability[i] : 0
                        });
                    }
                }
                root.hourly = blocks;

                const days = [];
                if (daily && daily.time) {
                    for (let i = 0; i < daily.time.length; i++) {
                        if (i === 0) {
                            // Today: reuse the real "right now" reading rather
                            // than a midday estimate, so day-nav offset 0
                            // exactly matches the current-conditions display.
                            days.push({
                                date: daily.time[0],
                                tempC: root.tempC,
                                feelsLikeC: root.feelsLikeC,
                                condition: root.condition,
                                icon: root.iconFor(root.condition),
                                humidity: root.humidity,
                                windKmph: root.windKmph,
                                chanceOfRain: blocks.length > 0 ? blocks[0].chanceOfRain : 0,
                                minTempC: daily.temperature_2m_min[i],
                                maxTempC: daily.temperature_2m_max[i]
                            });
                            continue;
                        }

                        // Future day: use that day's midday hourly block as a
                        // representative snapshot (no "current" reading exists).
                        let midday = null;
                        if (hourly && hourly.time) {
                            for (let h = 0; h < hourly.time.length; h++) {
                                if (!hourly.time[h].startsWith(daily.time[i])) continue;
                                if (hourly.time[h].endsWith("T12:00")) { midday = h; break; }
                                if (midday === null) midday = h;
                            }
                        }
                        const condCode = midday !== null ? hourly.weather_code[midday] : daily.weather_code[i];
                        days.push({
                            date: daily.time[i],
                            tempC: midday !== null ? hourly.temperature_2m[midday] : (daily.temperature_2m_max[i] + daily.temperature_2m_min[i]) / 2,
                            feelsLikeC: midday !== null ? hourly.temperature_2m[midday] : daily.temperature_2m_max[i],
                            condition: root.conditionFor(condCode),
                            icon: root.iconFor(root.conditionFor(condCode)),
                            humidity: root.humidity,
                            windKmph: root.windKmph,
                            chanceOfRain: (midday !== null && hourly.precipitation_probability) ? hourly.precipitation_probability[midday] : 0,
                            minTempC: daily.temperature_2m_min[i],
                            maxTempC: daily.temperature_2m_max[i]
                        });
                    }
                }
                root.daily = days;

                root.available = true;
                root._retryCount = 0;
            } catch (e) {
                root.available = false;
                root._scheduleRetry();
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
