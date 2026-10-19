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

    SwitchRow {
        key: "general.lockOnLogin"
        label: "Lock on login"
        description: "Lock the session as soon as you log in"
    }

    SectionHeader {
        text: "Commands"
        topPadding: Theme.spaceLg
    }

    GlyphText {
        text: "Command each power button runs. Separate arguments with spaces."
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
