pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    SwitchRow {
        key: "session.enabled"
        label: "Enabled"
    }

    SectionHeader {
        text: "Commands"
        topPadding: Theme.spaceLg
    }

    GlyphText {
        text: "argv run by each session button; separate arguments with spaces."
        role: "small"
        dim: true
        topPadding: Theme.spaceXs
    }

    Repeater {
        model: Object.keys(Config.session.commands ?? {})

        ArgvRow {
            required property string modelData
            key: "session.commands." + modelData
            label: SettingsStore.humanize(modelData)
        }
    }
}
