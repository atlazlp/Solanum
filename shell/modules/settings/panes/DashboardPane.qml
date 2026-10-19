import QtQuick
import qs.theme
import qs.components
import qs.modules.settings
import "../Validators.js" as Validators

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
        label: "Refresh interval"
        description: "How often the CPU, memory and other meters update"
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
        description: "lat,lon or a place name for open-meteo; empty uses IP geolocation"
        placeholder: "e.g. -23.55,-46.63"
        validate: t => Validators.weather(t)
    }

    SwitchRow {
        key: "dashboard.weather.useFahrenheit"
        label: "Fahrenheit"
    }

    SwitchRow {
        key: "dashboard.weather.useTwelveHourClock"
        label: "12-hour clock"
    }
}
