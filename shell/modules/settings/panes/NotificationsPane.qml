import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    SwitchRow {
        key: "notifs.enabled"
        label: "Popups"
        description: "Show notification popups (the ship log still records them)"
    }

    SwitchRow {
        key: "notifs.actionOnClick"
        label: "Action on click"
        description: "Clicking a popup triggers its default action"
    }

    NumberRow {
        key: "notifs.defaultTimeout"
        label: "Popup timeout"
        description: "How long a popup stays when the app does not set its own time. 0 keeps it up."
        from: 0
        to: 60
        step: 0.5
        displayScale: 0.001
        suffix: "s"
        decimals: 1
        fallback: 5000
    }

    NumberRow {
        key: "notifs.criticalTimeout"
        label: "Critical timeout"
        description: "Seconds before a critical notification closes (0 = stay until dismissed)"
        from: 0
        to: 120
        step: 0.5
        displayScale: 0.001
        suffix: "s"
        decimals: 1
    }

    NumberRow {
        key: "notifs.maxPopups"
        label: "Max popups"
        from: 1
        to: 20
        fallback: 5
    }

    SectionHeader {
        text: "Signals"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "sidebar.showOnHover"
        label: "Open on hover"
        description: "Hovering the bottom-right corner opens the Signals sidebar"
    }

    SectionHeader {
        text: "Ship log"
        topPadding: Theme.spaceLg
    }

    NumberRow {
        key: "shiplog.maxEntries"
        label: "Max entries"
        description: "Notification history cap"
        from: 50
        to: 5000
        step: 50
        fallback: 500
    }

    NumberRow {
        key: "shiplog.retentionDays"
        label: "Retention"
        description: "Entries older than this are dropped"
        from: 1
        to: 365
        suffix: "days"
        fallback: 30
    }

    SectionHeader {
        text: "Toasts"
        topPadding: Theme.spaceLg
    }

    GlyphText {
        text: "Short notes from the shell itself. App notifications are separate and still go to the ship log."
        role: "small"
        dim: true
        topPadding: Theme.spaceXs
        bottomPadding: Theme.spaceSm
    }

    SwitchRow {
        key: "utilities.toasts.configLoaded"
        label: "Config reloaded"
    }

    SwitchRow {
        key: "utilities.toasts.vpnChanged"
        label: "VPN"
        description: "When the VPN connects or drops"
    }

    SwitchRow {
        key: "utilities.toasts.gameModeChanged"
        label: "Game mode"
    }

    SwitchRow {
        key: "utilities.toasts.audioOutputChanged"
        label: "Speaker changes"
    }

    SwitchRow {
        key: "utilities.toasts.audioInputChanged"
        label: "Microphone changes"
    }

    SwitchRow {
        key: "utilities.toasts.nowPlaying"
        label: "Now playing"
    }

    SwitchRow {
        key: "utilities.toasts.kbLayoutChanged"
        label: "Keyboard layout"
    }

    SwitchRow {
        key: "utilities.toasts.capsLockChanged"
        label: "Caps Lock"
    }

    SwitchRow {
        key: "utilities.toasts.numLockChanged"
        label: "Num Lock"
    }
}
