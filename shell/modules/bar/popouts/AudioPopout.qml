pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.theme
import qs.components
import qs.services
import qs.utils

// Output/input device pickers, analog port switch and a horizontal volume slider.
Column {
    id: root

    property var host: null
    spacing: Theme.spaceSm
    width: 280

    SectionHeader { text: "Output" }

    Repeater {
        model: Audio.sinks

        HexButton {
            required property PwNode modelData
            width: root.width
            maxWidth: root.width
            flat: true
            icon: Audio.sink === modelData ? "radio_button_checked" : "radio_button_unchecked"
            text: modelData.description || modelData.name
            active: Audio.sink === modelData
            padding: Theme.spaceXs
            onClicked: Audio.setAudioSink(modelData)
        }
    }

    Row {
        visible: Audio.analogPortsAvailable
        spacing: Theme.spaceSm

        HexButton {
            icon: "speaker"
            text: "Speakers"
            active: Audio.analogActivePort === "speakers"
            padding: Theme.spaceXs
            onClicked: Audio.setAnalogSpeakers()
        }

        HexButton {
            icon: "headphones"
            text: "Headphones"
            active: Audio.analogActivePort === "headphones"
            padding: Theme.spaceXs
            onClicked: Audio.setAnalogHeadphones()
        }
    }

    SectionHeader { text: "Input" }

    Repeater {
        model: Audio.sources

        HexButton {
            required property PwNode modelData
            width: root.width
            maxWidth: root.width
            flat: true
            icon: Audio.source === modelData ? "radio_button_checked" : "radio_button_unchecked"
            text: modelData.description || modelData.name
            active: Audio.source === modelData
            padding: Theme.spaceXs
            onClicked: Audio.setAudioSource(modelData)
        }
    }

    SectionHeader { text: `Volume ${Audio.muted ? "(muted)" : Math.round(Audio.volume * 100) + "%"}` }

    NomaiSlider {
        orientation: Qt.Horizontal
        length: root.width
        thickness: 24
        icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
        value: Audio.volume
        to: Audio.maxVolume
        step: Audio.increment
        muted: Audio.muted
        onMoved: v => Audio.setVolume(v)
    }

    Row {
        spacing: Theme.spaceSm

        HexButton {
            icon: Audio.muted ? "volume_off" : "volume_up"
            text: Audio.muted ? "Unmute" : "Mute"
            padding: Theme.spaceXs
            onClicked: Audio.toggleMute()
        }

        HexButton {
            icon: "refresh"
            text: "Reload mic"
            padding: Theme.spaceXs
            onClicked: Audio.reloadMicrophone()
        }

        HexButton {
            icon: "tune"
            text: "Mixer"
            padding: Theme.spaceXs
            onClicked: {
                Visibilities.open("audioMixer", null);
                root.host?.hide();
            }
        }
    }
}
