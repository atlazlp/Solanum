import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils

// Three vertical sliders (volume, mic, brightness) at the right edge. Loaded by the "osd" slot.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property var monitor: screen ? Brightness.getMonitorForScreen(screen) : null

    padding: Theme.spaceMd
    chamfer: Theme.chamferMd
    fill: Theme.ink1
    glow: true
    ticks: true

    Row {
        spacing: Theme.spaceMd

        NomaiSlider {
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            value: Audio.volume
            to: Audio.maxVolume
            step: Audio.increment
            muted: Audio.muted
            onMoved: v => Audio.setVolume(v)
        }

        NomaiSlider {
            visible: Config.osd.showMicrophone !== false
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            value: Audio.sourceVolume
            to: Audio.maxVolume
            step: Audio.increment
            muted: Audio.sourceMuted
            accent: Theme.spark
            onMoved: v => Audio.setSourceVolume(v)
        }

        NomaiSlider {
            visible: Config.osd.showBrightness !== false && root.monitor !== null
            icon: Icons.getBrightnessIcon(value)
            value: root.monitor?.brightness ?? 0
            step: Brightness.increment
            accent: Theme.ember
            onMoved: v => root.monitor?.setBrightness(v)
        }
    }
}
