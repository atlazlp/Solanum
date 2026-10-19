pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.modules.settings
import "../Validators.js" as Validators

SettingsPane {
    SwitchRow {
        key: "launcher.enabled"
        label: "Enabled"
    }

    SwitchRow {
        key: "launcher.showOnHover"
        label: "Open on hover"
        description: "Hovering the bottom edge opens the launcher. Which screens do this is under Screens."
    }

    NumberRow {
        key: "launcher.maxShown"
        label: "Rows shown"
        from: 3
        to: 30
        fallback: 10
    }

    NumberRow {
        key: "launcher.maxResults"
        label: "Max results"
        from: 5
        to: 200
        step: 5
        fallback: 40
    }

    NumberRow {
        key: "launcher.width"
        label: "Width"
        from: 400
        to: 1400
        step: 20
        suffix: "px"
        fallback: 640
    }

    NumberRow {
        key: "launcher.emojiColumns"
        label: "Emoji columns"
        from: 4
        to: 16
        fallback: 8
    }

    SectionHeader {
        text: "Prefixes"
        topPadding: Theme.spaceLg
    }

    Repeater {
        model: Object.keys(Config.launcher.prefixes ?? {})

        TextRow {
            required property string modelData
            key: "launcher.prefixes." + modelData
            label: SettingsStore.humanize(modelData)
            description: "What you type to open " + SettingsStore.humanize(modelData).toLowerCase()
            fieldWidth: 120
            mono: true
        }
    }

    SectionHeader {
        text: "Entries"
        topPadding: Theme.spaceLg
    }

    ListRow {
        key: "launcher.favourites"
        label: "Favourites"
        description: "Desktop ids pinned to the top (e.g. org.gnome.Nautilus)"
        placeholder: "desktop id..."
        mono: true
    }

    ListRow {
        key: "launcher.hidden"
        label: "Hidden"
        description: "Regular expressions matched against desktop ids; matches are never listed"
        placeholder: "regex..."
        mono: true
        validateItem: t => Validators.regex(t)
    }
}
