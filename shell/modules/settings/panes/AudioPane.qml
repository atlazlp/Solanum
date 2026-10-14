import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    NumberRow {
        key: "audio.increment"
        label: "Volume step"
        description: "Fraction per key press / wheel notch"
        from: 0.01
        to: 0.5
        step: 0.01
        fallback: 0.1
    }

    NumberRow {
        key: "audio.maxVolume"
        label: "Max volume"
        description: "1 = 100 %; values above allow over-amplification"
        from: 0.5
        to: 2
        step: 0.05
        fallback: 1
    }

    TextRow {
        key: "audio.analogSinkId"
        label: "Analog sink id"
        description: "Pipewire node name whose speakers / headphones port is toggled"
        placeholder: "11_00.6.analog-stereo"
        mono: true
    }

    SectionHeader {
        text: "Brightness"
        topPadding: Theme.spaceLg
    }

    NumberRow {
        key: "brightness.increment"
        label: "Brightness step"
        from: 0.01
        to: 0.5
        step: 0.01
        fallback: 0.1
    }
}
