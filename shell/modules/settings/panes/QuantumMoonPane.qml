import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    SwitchRow {
        key: "quantumMoon.enabled"
        label: "Planet panel"
        description: "Show the Solanum ring"
    }

    SwitchRow {
        key: "quantumMoon.showOnHover"
        label: "Open on hover"
        description: "Hovering the top-right corner opens the panel"
    }

    SwitchRow {
        key: "quantumMoon.shuffleOnIdle"
        label: "Shuffle on return"
        description: "Pick a random planet when you come back, unless the scout is locked"
    }

    SectionHeader {
        text: "Wallpaper"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "quantumMoon.background.enabled"
        label: "Planet wallpapers"
        description: "Draw each planet's still image behind every screen"
    }

    ComboRow {
        key: "quantumMoon.background.centerMode"
        label: "Centre screen"
        description: "The live solar system, or the recorded video. The Eye always plays its video."
        comboWidth: 240
        model: [
            { value: "scene", label: "Live solar system" },
            { value: "video", label: "Recorded video" }
        ]
    }

    NumberRow {
        key: "quantumMoon.background.sceneSpeed"
        label: "Orbit speed"
        description: "How fast the planets move. 1 matches the game's loop."
        from: 0.25
        to: 32
        step: 0.25
        decimals: 2
        fallback: 4
    }

    SwitchRow {
        key: "quantumMoon.background.desktopClock.enabled"
        label: "Desktop clock"
        description: "Time drawn over the wallpaper"
    }

    ComboRow {
        key: "quantumMoon.background.desktopClock.position"
        label: "Clock position"
        model: [
            { value: "top-left", label: "Top left" },
            { value: "top-right", label: "Top right" },
            { value: "bottom-left", label: "Bottom left" },
            { value: "bottom-right", label: "Bottom right" },
            { value: "center", label: "Centre" }
        ]
    }

    SectionHeader {
        text: "Sound waves"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "quantumMoon.background.visualiser.enabled"
        label: "Sound waves"
        description: "Audio bars on the wallpaper, beside the clock"
    }

    NumberRow {
        key: "quantumMoon.background.visualiser.bars"
        label: "Bar count"
        description: "How many bars the wave is drawn with"
        from: 16
        to: 256
        step: 16
        fallback: 128
    }

    ComboRow {
        key: "quantumMoon.background.visualiser.ringMode"
        label: "Ring follows"
        description: "Move the ring with Solanum, or keep it on one planet"
        comboWidth: 240
        model: [
            { value: "follow_solanum", label: "Solanum" },
            { value: "fixed", label: "One planet" }
        ]
    }

    ComboRow {
        key: "quantumMoon.background.visualiser.fixedPlanet"
        label: "Planet"
        description: "Used when the ring stays on one planet"
        comboWidth: 240
        model: [
            { value: "giants_deep", label: "Giant's Deep" },
            { value: "timber_hearth", label: "Timber Hearth" },
            { value: "hourglass_twins", label: "Hourglass Twins" },
            { value: "brittle_hollow", label: "Brittle Hollow" },
            { value: "dark_bramble", label: "Dark Bramble" }
        ]
        visible: {
            void store.generation;
            return store.has(key) && store.get("quantumMoon.background.visualiser.ringMode", "follow_solanum") === "fixed";
        }
    }

    SectionHeader {
        text: "Engine"
        topPadding: Theme.spaceLg
    }

    SettingRow {
        label: "Solar system scene"
        description: "Godot project shipped with the engine. A path in the godot-root file overrides it."

        GlyphText {
            text: Paths.scene
            role: "mono"
            dim: true
        }
    }

    SettingRow {
        key: "qm.root"
        label: "Engine root"
        description: "Read-only. The root file beside shell.json, or QM_ROOT. shell.json override: " + (Config.qm.root || "none")

        GlyphText {
            text: Paths.qmRoot
            role: "mono"
            dim: true
        }
    }

    SettingRow {
        label: "Modes"

        GlyphText {
            text: Paths.modes
            role: "mono"
            dim: true
        }
    }
}
