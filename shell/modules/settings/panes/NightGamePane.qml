import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    NumberRow {
        key: "nightlight.temperature"
        label: "Night light temperature"
        description: "hyprsunset Kelvin used when no per-planet value applies"
        from: 1000
        to: 10000
        step: 100
        suffix: "K"
        fallback: 4000
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
        label: "Pause video wallpaper"
        description: "Pause mpvpaper over IPC while game mode is on"
    }
}
