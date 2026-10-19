import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    SliderRow {
        id: tempRow
        key: "nightlight.temperature"
        label: "Colour temperature"
        description: "Used when the current planet does not set its own"
        from: 1000
        to: 10000
        step: 100
        suffix: "K"
        decimals: 0
        fallback: 4000
        accent: Theme.mix(Theme.ember, Theme.spark, Math.max(0, Math.min(1, (((typeof tempRow.current === "number" ? tempRow.current : 4000) - 1000) / 9000))))
    }

    SectionHeader {
        text: "Game mode"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "gameMode.autoVpnOff"
        label: "Disconnect VPN"
        description: "Bring the VPN down when game mode turns on"
    }

    SwitchRow {
        key: "gameMode.pauseVideo"
        label: "Pause the centre wallpaper"
        description: "Stop the live scene and the recorded video while a game is focused"
    }
}
