import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    SwitchRow {
        key: "quantumMoon.enabled"
        label: "Planet panel"
        description: "Show the Quantum Moon planet panel"
    }

    SwitchRow {
        key: "quantumMoon.showOnHover"
        label: "Open on hover"
        description: "Hovering the top-right corner opens the panel"
    }

    SwitchRow {
        key: "quantumMoon.shuffleOnIdle"
        label: "Shuffle on idle"
        description: "Random planet on resume / idle return when not scout-locked"
    }

    SectionHeader {
        text: "Background"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "quantumMoon.background.enabled"
        label: "Wallpaper layer"
        description: "Draw the planet wallpaper behind every screen"
    }

    SwitchRow {
        key: "quantumMoon.background.desktopClock.enabled"
        label: "Desktop clock"
    }

    ComboRow {
        key: "quantumMoon.background.desktopClock.position"
        label: "Clock position"
        model: ["top-left", "top-right", "bottom-left", "bottom-right", "center"]
    }

    SectionHeader {
        text: "Engine"
        topPadding: Theme.spaceLg
    }

    SettingRow {
        key: "qm.root"
        label: "Engine root"
        description: "Read-only. Override in ~/.config/quantum-moon/root or QM_ROOT; shell.json qm.root: " + (Config.qm.root || "(unset)")

        GlyphText {
            text: Paths.qmRoot
            role: "mono"
            dim: true
        }
    }

    SettingRow {
        label: "Modes directory"

        GlyphText {
            text: Paths.modes
            role: "mono"
            dim: true
        }
    }
}
