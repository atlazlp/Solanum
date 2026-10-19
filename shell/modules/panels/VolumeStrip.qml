pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils

// Sleek right-edge volume strip: system + apps as thin vertical bars, mute icon under each.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property list<var> appStreams: Audio.streams.filter(s => Audio.isMixerStream(s))

    padding: Theme.spaceSm
    chamfer: Theme.chamferMd
    corners: 9
    fill: Theme.alpha(Theme.ink1, 0.94)
    glow: false
    ticks: false
    clip: false
    implicitWidth: Math.min(row.implicitWidth + padding * 2, (screen?.width ?? 800) * 0.4)
    implicitHeight: row.implicitHeight + padding * 2

    function reveal(): void {
        revealer.trigger();
    }

    GlyphReveal {
        id: revealer
        anchors.fill: parent
        autoTrigger: false

        Flickable {
            anchors.fill: parent
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            interactive: contentWidth > width

            Row {
                id: row
                spacing: Theme.spaceSm

                VolumeColumn {
                    label: "System"
                    icon: "volume_up"
                    value: Audio.volume
                    muted: Audio.muted
                    to: Audio.maxVolume
                    accent: Theme.line
                    onMoved: v => Audio.setVolume(v)
                    onMuteToggled: Audio.toggleMute()
                }

                Repeater {
                    model: root.appStreams

                    VolumeColumn {
                        required property PwNode modelData
                        label: Audio.streamTooltip(modelData, root.appStreams)
                        appId: modelData.properties["application.id"]
                            || modelData.properties["application.name"]
                            || modelData.properties["media.name"]
                            || ""
                        value: modelData.audio?.volume ?? 0
                        muted: !!modelData.audio?.muted
                        to: Audio.maxVolume
                        accent: Theme.spark
                        onMoved: v => Audio.setStreamVolume(modelData, v)
                        onMuteToggled: Audio.setStreamMuted(modelData, !muted)
                    }
                }
            }
        }
    }

    component VolumeColumn: Item {
        id: vcol

        property string label: ""
        property string icon: "volume_up"
        property string appId: ""
        property real value: 0
        property real to: 1
        property bool muted: false
        property color accent: Theme.line
        signal moved(real value)
        signal muteToggled()

        width: 34
        height: slider.height + Theme.spaceXs + iconBox.height

        NomaiSlider {
            id: slider
            orientation: Qt.Vertical
            length: 112
            thickness: 26
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            value: vcol.value
            to: vcol.to
            step: Audio.increment
            muted: vcol.muted
            accent: vcol.accent
            onMoved: v => vcol.moved(v)
        }

        Item {
            id: iconBox
            width: parent.width
            height: Theme.sizeIcon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: slider.bottom
            anchors.topMargin: Theme.spaceXs

            AppIcon {
                visible: vcol.appId.length > 0
                anchors.centerIn: parent
                appId: vcol.appId
                fallbackIcon: "graphic_eq"
                size: Theme.sizeIcon - 2
                opacity: vcol.muted ? 0.4 : 1
            }

            GlyphIcon {
                visible: vcol.appId.length === 0
                anchors.centerIn: parent
                size: Theme.sizeIcon - 2
                icon: vcol.muted || vcol.value <= 0 ? "volume_off" : vcol.icon
                color: vcol.muted || vcol.value <= 0 ? Theme.textDim : vcol.accent
                animate: true
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: vcol.muteToggled()
            }
        }

        HoverHandler {
            id: colHover
            cursorShape: Qt.PointingHandCursor
        }

        NomaiTooltip {
            anchorItem: vcol
            text: vcol.label || "Audio"
            show: colHover.hovered && (vcol.label || "").length > 0
            delay: 120
        }
    }
}
