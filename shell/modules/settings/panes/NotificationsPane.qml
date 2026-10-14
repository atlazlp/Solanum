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

    SwitchRow {
        key: "notifs.expire"
        label: "Auto-close"
    }

    NumberRow {
        key: "notifs.defaultTimeout"
        label: "Default timeout"
        description: "Milliseconds before a popup without its own timeout closes (0 = never)"
        from: 0
        to: 60000
        step: 500
        suffix: "ms"
        fallback: 5000
    }

    NumberRow {
        key: "notifs.defaultExpireTimeout"
        label: "Default expire timeout"
        from: 0
        to: 60000
        step: 500
        suffix: "ms"
    }

    NumberRow {
        key: "notifs.criticalTimeout"
        label: "Critical timeout"
        description: "Timeout for critical notifications (0 = stay until dismissed)"
        from: 0
        to: 120000
        step: 500
        suffix: "ms"
    }

    NumberRow {
        key: "notifs.maxPopups"
        label: "Max popups"
        from: 1
        to: 20
        fallback: 5
    }

    NumberRow {
        key: "notifs.groupPreviewNum"
        label: "Group preview"
        from: 1
        to: 10
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
}
