// Run the service's real JS methods with only HTTP and QML timers replaced.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source = readFileSync(new URL('../../.config/quickshell/helios/services/Weather.qml', import.meta.url), 'utf8');
function service() {
    const requests = [];
    class Request {
        static DONE = 4;
        open(method, url) { this.url = url; }
        send() { requests.push(this); }
        abort() {}
        respond(data, status = 200) {
            this.status = status; this.responseText = JSON.stringify(data); this.readyState = 4;
            this.onreadystatechange();
        }
    }
    const timer = () => ({ restart() {}, stop() {} });
    const settingsAdapter = { locationOverride: '', locationName: '', temperatureUnit: 'celsius', windUnit: 'kmh', refreshMinutes: 20, animationsEnabled: true };
    const root = { loading: false, available: false, error: '', lastUpdated: 0, searching: false,
        searchResults: [], searchError: '', _searchGeneration: 0, _forecastGeneration: 0, _retryCount: 0,
        settingsFile: { writeAdapter() {} }, saveTimer: timer(), retryTimer: timer(), requestTimer: timer(), searchTimer: timer() };
    for (const key of Object.keys(settingsAdapter)) Object.defineProperty(root, key, { get: () => settingsAdapter[key] });
    const context = vm.createContext({ root, settingsAdapter, XMLHttpRequest: Request, Date, console });
    for (const match of source.matchAll(/^    function (\w+)\(([^)]*)\) \{([\s\S]*?)^    \}/gm)) {
        root[match[1]] = vm.runInContext(`(function(${match[2]}) {${match[3]}})`, context);
    }
    return { root, requests };
}
const forecast = { current: { temperature_2m: 25, apparent_temperature: 27, weather_code: 2, relative_humidity_2m: 60, wind_speed_10m: 36 } };
{
    const { root, requests } = service();
    assert.equal(typeof root.searchLocations, 'function', 'city search exists');
    root.searchLocations('Paris');
    const old = requests.at(-1);
    root.searchLocations('Tokyo');
    requests.at(-1).respond({ results: [{ name: 'Tokyo', country: 'Japan', latitude: 35, longitude: 139 }] });
    old.respond({ results: [{ name: 'Paris', latitude: 48, longitude: 2 }] });
    assert.equal(root.searchResults[0].name, 'Tokyo', 'stale search cannot replace current results');
    root.searchLocations('');
    assert.equal(root.searchResults.length, 0, 'clearing search clears results');
    assert.equal(root.searching, false);
    root.searchLocations('Missing');
    requests.at(-1).respond({});
    assert.match(root.searchError, /no.*found/i, 'empty results explained');
    root.searchLocations('Offline');
    requests.at(-1).respond({}, 503);
    assert.ok(root.searchError, 'search errors visible');
    assert.equal(root.searching, false);
}
{
    const { root, requests } = service();
    root.setLocation('14,121');
    const old = requests.at(-1);
    root.selectLocation({ name: 'Paris', admin1: 'Texas', country: 'United States', latitude: 33.66, longitude: -95.55 });
    const selected = requests.at(-1);
    assert.match(selected.url, /latitude=33.66&longitude=-95.55/, 'selected city coordinates requested');
    selected.respond(forecast);
    old.respond({ current: { ...forecast.current, temperature_2m: -10 } });
    assert.equal(root.tempC, 25, 'old location response ignored');
    assert.equal(root.location, 'Paris, Texas, United States');
    assert.equal(root.locationOverride, '33.66,-95.55');
    assert.ok(root.lastUpdated > 0, 'success records update timestamp');
    root.refresh();
    requests.at(-1).respond({}, 503);
    assert.ok(root.error, 'refresh failure explained');
    assert.equal(root.available, true, 'refresh failure preserves last forecast');
    root.refresh();
    requests.at(-1).respond(forecast);
    assert.equal(root.error, '', 'successful refresh clears error');
    const count = requests.length;
    root.setLocation('91,181');
    assert.equal(requests.length, count, 'invalid coordinates make no request');
    assert.equal(root.locationOverride, '33.66,-95.55', 'invalid coordinates do not overwrite location');
}
console.log('WEATHER_REQUESTS_TEST_PASS');
