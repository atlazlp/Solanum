pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

// Weather via open-meteo (curl). Location from Config.dashboard.weather.location ("lat,lon" or a
// city name) or ipinfo.io geolocation. Cached in ~/.cache/solanum/weather.json, refreshed hourly.
Singleton {
    id: root

    property string city: ""
    property string loc: ""            // "lat,lon"
    property var cc: null              // current conditions
    property list<var> forecast: []    // 7 days
    property list<var> hourlyForecast: []
    property double fetchedAt: 0       // ms epoch of last successful fetch
    property bool loading: false
    property string error: ""

    readonly property bool useFahrenheit: Config.get("dashboard.weather.useFahrenheit", false)
    readonly property bool twelveHour: Config.get("dashboard.weather.useTwelveHourClock", false)
    readonly property string configLocation: Config.get("dashboard.weather.location", "")
    readonly property int maxAge: 3600000

    readonly property bool hasData: cc !== null
    readonly property string icon: cc ? Icons.getWeatherIcon(String(cc.weatherCode)) : "cloud_off"
    readonly property string description: cc?.weatherDesc ?? "No weather"
    readonly property string temp: cc ? (useFahrenheit ? `${cc.tempF}°F` : `${cc.tempC}°C`) : "--°"
    readonly property string feelsLike: cc ? (useFahrenheit ? `${cc.feelsLikeF}°F` : `${cc.feelsLikeC}°C`) : "--°"
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? fmtTime(cc.sunrise) : "--:--"
    readonly property string sunset: cc ? fmtTime(cc.sunset) : "--:--"

    function fmtTime(s: string): string {
        const d = new Date(String(s).replace(" ", "T"));
        if (isNaN(d.getTime()))
            return "--:--";
        return Qt.formatDateTime(d, twelveHour ? "h:mm AP" : "HH:mm");
    }

    function tempFor(c: int, f: int): string {
        return useFahrenheit ? `${f}°` : `${c}°`;
    }

    function toFahrenheit(c: real): real {
        return c * 9 / 5 + 32;
    }

    function reload(): void {
        if (loading)
            return;
        error = "";
        if (configLocation) {
            if (configLocation.indexOf(",") !== -1 && !isNaN(parseFloat(configLocation.split(",")[0]))) {
                loc = configLocation.split(",").map(s => s.trim()).join(",");
                fetchWeather();
            } else {
                geocode.query = configLocation;
                geocode.running = true;
            }
        } else if (loc) {
            fetchWeather();
        } else {
            ipinfo.running = true;
        }
    }

    function fetchWeather(): void {
        const url = weatherUrl();
        if (url === "")
            return;
        fetcher.url = url;
        fetcher.running = true;
    }

    function weatherUrl(): string {
        if (!loc || loc.indexOf(",") === -1)
            return "";
        const [lat, lon] = loc.split(",").map(s => s.trim());
        const params = [`latitude=${lat}`, `longitude=${lon}`, "hourly=weather_code,temperature_2m", "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset", "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m", "timezone=auto", "forecast_days=7"];
        return "https://api.open-meteo.com/v1/forecast?" + params.join("&");
    }

    function condition(code): string {
        const conditions = {
            "0": "Clear", "1": "Clear", "2": "Partly cloudy", "3": "Overcast",
            "45": "Fog", "48": "Fog",
            "51": "Drizzle", "53": "Drizzle", "55": "Drizzle", "56": "Freezing drizzle", "57": "Freezing drizzle",
            "61": "Light rain", "63": "Rain", "65": "Heavy rain", "66": "Light rain", "67": "Heavy rain",
            "71": "Light snow", "73": "Snow", "75": "Heavy snow", "77": "Snow",
            "80": "Light rain", "81": "Rain", "82": "Heavy rain", "85": "Light snow showers", "86": "Heavy snow showers",
            "95": "Thunderstorm", "96": "Thunderstorm with hail", "99": "Thunderstorm with hail"
        };
        return conditions[String(code)] ?? "Unknown";
    }

    function applyJson(json): bool {
        if (!json || !json.current || !json.daily)
            return false;
        cc = {
            weatherCode: json.current.weather_code,
            weatherDesc: condition(json.current.weather_code),
            tempC: Math.round(json.current.temperature_2m),
            tempF: Math.round(toFahrenheit(json.current.temperature_2m)),
            feelsLikeC: Math.round(json.current.apparent_temperature),
            feelsLikeF: Math.round(toFahrenheit(json.current.apparent_temperature)),
            humidity: json.current.relative_humidity_2m,
            windSpeed: json.current.wind_speed_10m,
            isDay: json.current.is_day,
            sunrise: json.daily.sunrise[0].replace("T", " "),
            sunset: json.daily.sunset[0].replace("T", " ")
        };
        const days = [];
        for (let i = 0; i < json.daily.time.length; i++) {
            days.push({
                date: json.daily.time[i],
                day: Qt.formatDate(new Date(json.daily.time[i] + "T12:00:00"), "ddd"),
                maxTempC: Math.round(json.daily.temperature_2m_max[i]),
                maxTempF: Math.round(toFahrenheit(json.daily.temperature_2m_max[i])),
                minTempC: Math.round(json.daily.temperature_2m_min[i]),
                minTempF: Math.round(toFahrenheit(json.daily.temperature_2m_min[i])),
                weatherCode: json.daily.weather_code[i],
                desc: condition(json.daily.weather_code[i]),
                icon: Icons.getWeatherIcon(String(json.daily.weather_code[i]))
            });
        }
        forecast = days;
        const hours = [];
        const now = new Date();
        now.setMinutes(0, 0, 0);
        for (let i = 0; i < json.hourly.time.length && hours.length < 24; i++) {
            const t = new Date(json.hourly.time[i]);
            if (t < now)
                continue;
            hours.push({
                timestamp: json.hourly.time[i],
                hour: t.getHours(),
                label: Qt.formatTime(t, twelveHour ? "h AP" : "HH"),
                tempC: Math.round(json.hourly.temperature_2m[i]),
                tempF: Math.round(toFahrenheit(json.hourly.temperature_2m[i])),
                weatherCode: json.hourly.weather_code[i],
                icon: Icons.getWeatherIcon(String(json.hourly.weather_code[i]))
            });
        }
        hourlyForecast = hours;
        return true;
    }

    function saveCache(): void {
        try {
            cache.setText(JSON.stringify({ loc, city, fetchedAt, cc, forecast, hourlyForecast }, null, 2) + "\n");
        } catch (e) {
            console.warn("Weather: cache write failed", e);
        }
    }

    Process {
        id: ipinfo

        command: ["curl", "-sf", "--max-time", "10", "https://ipinfo.io/json"]
        onStarted: root.loading = true
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const r = JSON.parse(text);
                    if (r.loc) {
                        root.loc = r.loc;
                        root.city = r.city ?? "";
                        root.fetchWeather();
                        return;
                    }
                } catch (e) {}
                root.error = "No location";
            }
        }
    }

    Process {
        id: geocode

        property string query: ""
        command: ["curl", "-sf", "--max-time", "10", `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=1&language=en&format=json`]
        onStarted: root.loading = true
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const r = JSON.parse(text);
                    if (r.results?.length) {
                        root.loc = `${r.results[0].latitude},${r.results[0].longitude}`;
                        root.city = r.results[0].name;
                        root.fetchWeather();
                        return;
                    }
                } catch (e) {}
                root.error = "Unknown location";
                if (!root.loc)
                    ipinfo.running = true;
            }
        }
    }

    Process {
        id: fetcher

        property string url: ""
        command: ["curl", "-sf", "--max-time", "15", url]
        onStarted: root.loading = true
        onExited: code => {
            root.loading = false;
            if (code !== 0)
                root.error = "Weather unavailable";
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (root.applyJson(JSON.parse(text))) {
                        root.fetchedAt = Date.now();
                        root.error = "";
                        if (!root.city && root.loc)
                            reverseGeo.running = true;
                        root.saveCache();
                    }
                } catch (e) {
                    root.error = "Bad weather data";
                }
            }
        }
    }

    Process {
        id: reverseGeo

        command: ["curl", "-sf", "--max-time", "10", `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${root.loc.split(",")[0]}&longitude=${root.loc.split(",")[1] ?? ""}&localityLanguage=en`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const g = JSON.parse(text);
                    const c = g.city || g.locality;
                    if (c) {
                        root.city = c;
                        root.saveCache();
                    }
                } catch (e) {}
            }
        }
    }

    FileView {
        id: cache

        path: `${Paths.cache}/weather.json`
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                if (j.cc && !root.cc) {
                    root.cc = j.cc;
                    root.forecast = j.forecast ?? [];
                    root.hourlyForecast = j.hourlyForecast ?? [];
                    root.fetchedAt = j.fetchedAt ?? 0;
                    if (!root.configLocation) {
                        root.loc = j.loc ?? "";
                        root.city = j.city ?? "";
                    }
                }
            } catch (e) {}
            if (Date.now() - root.fetchedAt > root.maxAge)
                root.reload();
        }
        onLoadFailed: root.reload()
    }

    Timer {
        interval: root.maxAge
        running: true
        repeat: true
        onTriggered: root.reload()
    }

    Connections {
        target: Config
        function onReload(): void {
            if (root.configLocation)
                root.reload();
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Paths.cache])
}
