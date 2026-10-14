import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    SwitchRow {
        key: "dashboard.enabled"
        label: "Enabled"
    }

    SwitchRow {
        key: "dashboard.showOnHover"
        label: "Open on hover"
        description: "Hovering the top edge opens the dashboard"
    }

    NumberRow {
        key: "dashboard.resourceUpdateInterval"
        label: "Resource update interval"
        from: 500
        to: 10000
        step: 500
        suffix: "ms"
        fallback: 3000
    }

    NumberRow {
        key: "dashboard.historyLength"
        label: "Graph history"
        description: "Samples kept for the sparklines"
        from: 10
        to: 120
        step: 5
        fallback: 30
    }

    SectionHeader {
        text: "Weather"
        topPadding: Theme.spaceLg
    }

    TextRow {
        key: "dashboard.weather.location"
        label: "Location"
        description: "\"lat,lon\" or a place name for open-meteo; empty = IP geolocation"
        placeholder: "e.g. -23.55,-46.63"
    }

    TextRow {
        key: "services.weatherLocation"
        label: "Location"
        placeholder: "lat,lon"
    }

    SwitchRow {
        key: "dashboard.weather.useFahrenheit"
        label: "Fahrenheit"
    }

    SwitchRow {
        key: "services.useFahrenheit"
        label: "Fahrenheit"
    }

    SwitchRow {
        key: "dashboard.weather.useTwelveHourClock"
        label: "12-hour clock"
    }

    SectionHeader {
        text: "OSD"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "osd.enabled"
        label: "Enabled"
    }

    NumberRow {
        key: "osd.hideDelay"
        label: "Hide delay"
        from: 300
        to: 10000
        step: 100
        suffix: "ms"
        fallback: 2000
    }

    SwitchRow {
        key: "osd.showMicrophone"
        label: "Show microphone"
    }

    SwitchRow {
        key: "osd.showBrightness"
        label: "Show brightness"
    }
}
