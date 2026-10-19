import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    SliderRow {
        key: "audio.increment"
        label: "Volume step"
        description: "Change per key press or wheel notch"
        from: 1
        to: 50
        step: 1
        displayScale: 100
        suffix: "%"
        decimals: 0
        fallback: 0.1
    }

    SliderRow {
        key: "audio.maxVolume"
        label: "Max volume"
        description: "100% is unity; higher allows over-amplification"
        from: 50
        to: 200
        step: 5
        displayScale: 100
        suffix: "%"
        decimals: 0
        fallback: 1
    }

    TextRow {
        key: "audio.analogSinkId"
        label: "Analog sink id"
        description: "Pipewire node name whose speakers / headphones port is toggled"
        placeholder: "11_00.6.analog-stereo"
        mono: true
    }

    SwitchRow {
        key: "audio.showOnHover"
        label: "Volume on hover"
        description: "Hovering the right edge opens the volume panel"
    }

    SectionHeader {
        text: "Brightness"
        topPadding: Theme.spaceLg
    }

    SliderRow {
        key: "brightness.increment"
        label: "Brightness step"
        description: "Change per key press"
        from: 1
        to: 50
        step: 1
        displayScale: 100
        suffix: "%"
        decimals: 0
        fallback: 0.1
    }

    SectionHeader {
        text: "OSD"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "osd.enabled"
        label: "Enabled"
    }

    NumberRow {
        key: "osd.hideDelay"
        label: "Hide delay"
        description: "Seconds the OSD stays up"
        from: 0.3
        to: 10
        step: 0.1
        displayScale: 0.001
        suffix: "s"
        decimals: 1
        fallback: 2000
    }

    SwitchRow {
        key: "osd.showMicrophone"
        label: "Show microphone"
    }

    SwitchRow {
        key: "osd.showBrightness"
        label: "Show brightness"
    }
}
