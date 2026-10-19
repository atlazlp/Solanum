pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services
import qs.utils

// Compact mic popout: vertical volume + mute/unmute.
Column {
    id: root

    property var host: null
    spacing: Theme.spaceSm
    width: 56

    GlyphText {
        text: "Mic"
        role: "label"
        dim: true
        anchors.horizontalCenter: parent.horizontalCenter
    }

    NomaiSlider {
        orientation: Qt.Vertical
        length: 120
        thickness: 36
        anchors.horizontalCenter: parent.horizontalCenter
        icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
        value: Audio.sourceVolume
        to: Audio.maxVolume
        step: Audio.increment
        muted: Audio.sourceMuted
        accent: Theme.spark
        onMoved: v => Audio.setSourceVolume(v)
    }

    HexButton {
        anchors.horizontalCenter: parent.horizontalCenter
        icon: Audio.sourceMuted || Audio.sourceVolume <= 0 ? "mic_off" : "mic"
        text: Audio.sourceMuted || Audio.sourceVolume <= 0 ? "Unmute" : "Mute"
        shape: "chamfer"
        padding: Theme.spaceXs
        active: Audio.sourceMuted || Audio.sourceVolume <= 0
        onClicked: {
            if (Audio.sourceMuted || Audio.sourceVolume <= 0) {
                if (Audio.sourceMuted)
                    Audio.toggleSourceMute();
                if (Audio.sourceVolume <= 0)
                    Audio.setSourceVolume(Audio.increment);
            } else {
                Audio.toggleSourceMute();
            }
        }
    }

    HexButton {
        anchors.horizontalCenter: parent.horizontalCenter
        icon: "refresh"
        tooltip: "Reload microphone"
        shape: "hex"
        padding: Theme.spaceSm
        flat: true
        onClicked: Audio.reloadMicrophone()
    }
}
