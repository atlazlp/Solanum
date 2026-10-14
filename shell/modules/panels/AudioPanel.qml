pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.theme
import qs.components
import qs.services
import qs.utils

// Centre panel: output devices + analog port, per-app streams, input devices + mic.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property int contentWidth: 520
    readonly property int gap: Theme.spaceMd
    readonly property int appsMaxHeight: 200
    property bool echoCancel: false
    // hide PipeWire internals (echo-cancel module streams, Quickshell peak monitors)
    readonly property list<PwNode> appStreams: Audio.streams.filter(n => {
        const p = n.properties ?? {};
        const nn = p["node.name"] ?? n.name ?? "";
        return !nn.startsWith("echo-cancel") && p["media.name"] !== "Peak detect" && p["application.name"] !== "Quickshell";
    })

    function reveal(): void {
        reveal.trigger();
    }

    function updateEchoCancel(): void {
        echoCancel = Pipewire.nodes.values.some(n => (n.name ?? "").startsWith("echo-cancel"));
    }

    padding: Theme.spaceLg
    chamfer: Theme.chamferLg
    fill: Theme.ink
    glow: true
    ticks: true

    Component.onCompleted: {
        Audio.peakRefs++;
        updateEchoCancel();
    }
    Component.onDestruction: Audio.peakRefs--

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            root.updateEchoCancel();
        }
    }

    PwNodePeakMonitor {
        id: sourcePeak
        node: Audio.source
        enabled: !GameMode.enabled
    }

    GlyphReveal {
        id: reveal

        autoTrigger: false
        implicitWidth: root.contentWidth
        implicitHeight: inputSec.y + inputSec.height

        // ---- header ----
        Item {
            id: header
            width: root.contentWidth
            height: 40

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceSm

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                    fill: Audio.muted ? 0 : 1
                    color: Audio.muted ? Theme.textDim : Theme.line
                    animate: true
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Audio"
                    role: "title"
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "small"
                    dim: true
                    text: Audio.sink ? (Audio.sink.description || Audio.sink.name) : "no sink"
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceSm

                HexButton {
                    icon: "mic"
                    text: "Reload mic"
                    tooltip: "Restart the PipeWire capture (qm-audio-reload-mic.sh)"
                    onClicked: Audio.reloadMicrophone()
                }
            }
        }

        // ---- output ----
        Column {
            id: outputSec
            anchors.top: header.bottom
            anchors.topMargin: root.gap
            width: root.contentWidth
            spacing: Theme.spaceSm

            SectionHeader {
                text: "Output"
            }

            Repeater {
                model: Audio.sinks

                DeviceRow {
                    required property PwNode modelData
                    node: modelData
                    current: Audio.sink === modelData
                    onPicked: Audio.setAudioSink(modelData)
                }
            }

            Row {
                visible: Audio.analogPortsAvailable
                spacing: Theme.spaceSm

                HexButton {
                    icon: "speaker"
                    text: "Line-out"
                    active: Audio.analogActivePort === "speakers"
                    glow: active
                    padding: Theme.spaceXs
                    tooltip: `pactl set-sink-port ${Audio.analogPortSpeakers}`
                    onClicked: Audio.setAnalogSpeakers()
                }

                HexButton {
                    icon: "headphones"
                    text: "Headphones"
                    active: Audio.analogActivePort === "headphones"
                    glow: active
                    padding: Theme.spaceXs
                    tooltip: `pactl set-sink-port ${Audio.analogPortHeadphones}`
                    onClicked: Audio.setAnalogHeadphones()
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "small"
                    dim: true
                    text: Audio.analogActivePort === "" ? "analog port: unknown" : ""
                }
            }

            VolumeRow {
                label: "Master"
                icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                value: Audio.volume
                to: Audio.maxVolume
                step: Audio.increment
                muted: Audio.muted
                level: Audio.peak
                onMoved: v => Audio.setVolume(v)
                onMuteToggled: Audio.toggleMute()
            }
        }

        // ---- apps ----
        Column {
            id: appsSec
            anchors.top: outputSec.bottom
            anchors.topMargin: root.gap
            width: root.contentWidth
            spacing: Theme.spaceSm

            SectionHeader {
                text: `Apps (${root.appStreams.length})`
            }

            GlyphText {
                visible: root.appStreams.length === 0
                role: "small"
                dim: true
                text: "no audio streams"
            }

            Flickable {
                width: parent.width
                height: Math.min(root.appsMaxHeight, appsCol.implicitHeight)
                contentHeight: appsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.appStreams.length > 0

                Column {
                    id: appsCol
                    width: parent.width
                    spacing: Theme.spaceXs

                    Repeater {
                        model: root.appStreams

                        VolumeRow {
                            required property PwNode modelData
                            readonly property string appName: Audio.streamName(modelData)
                            appId: appName
                            label: appName
                            sub: modelData.properties["media.name"] ?? ""
                            icon: ""
                            value: modelData.audio?.volume ?? 0
                            to: Audio.maxVolume
                            step: Audio.increment
                            muted: !!modelData.audio?.muted
                            showLevel: false
                            onMoved: v => Audio.setStreamVolume(modelData, v)
                            onMuteToggled: Audio.setStreamMuted(modelData, !(modelData.audio?.muted ?? false))
                        }
                    }
                }
            }
        }

        // ---- input ----
        Column {
            id: inputSec
            anchors.top: appsSec.bottom
            anchors.topMargin: root.gap
            width: root.contentWidth
            spacing: Theme.spaceSm

            SectionHeader {
                text: "Input"
            }

            Repeater {
                model: Audio.sources

                DeviceRow {
                    required property PwNode modelData
                    node: modelData
                    current: Audio.source === modelData
                    onPicked: Audio.setAudioSource(modelData)
                }
            }

            VolumeRow {
                label: "Microphone"
                icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                value: Audio.sourceVolume
                to: Audio.maxVolume
                step: Audio.increment
                muted: Audio.sourceMuted
                level: sourcePeak.peak
                onMoved: v => Audio.setSourceVolume(v)
                onMuteToggled: Audio.toggleSourceMute()
            }

            Row {
                spacing: Theme.spaceSm

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.echoCancel ? "noise_aware" : "noise_control_off"
                    size: Theme.sizeIcon - 2
                    fill: root.echoCancel ? 1 : 0
                    color: root.echoCancel ? Theme.success : Theme.textDim
                    animate: true
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "small"
                    dim: !root.echoCancel
                    text: root.echoCancel ? "echo cancel active (echo-cancel-* nodes present)" : "echo cancel inactive"
                }
            }
        }
    }

    // ---- building blocks ----
    component DeviceRow: NomaiFrame {
        id: dev

        property PwNode node: null
        property bool current: false
        signal picked()

        width: root.contentWidth
        implicitHeight: 30
        padding: 0
        chamfer: Theme.chamferSm
        z: hover.hovered ? 1 : 0
        fill: hover.hovered ? Theme.ink2 : (current ? Theme.alpha(Theme.line, 0.12) : "transparent")
        lineOpacity: hover.hovered || current ? (hover.hovered ? 1 : 0.55) : 0

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceSm

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: dev.current ? "radio_button_checked" : "radio_button_unchecked"
                size: Theme.sizeIcon - 2
                fill: dev.current ? 1 : 0
                color: dev.current ? Theme.line : Theme.textDim
                animate: true
            }

            GlyphText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.sizeIcon - Theme.spaceSm
                text: dev.node ? (dev.node.description || dev.node.name) : ""
                dim: !dev.current
            }
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: dev.picked()
        }

        NomaiTooltip {
            text: dev.node?.name ?? ""
            show: hover.hovered && text !== ""
            anchors.top: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: Theme.spaceXs
        }
    }

    component VolumeRow: Item {
        id: vr

        property string label: ""
        property string sub: ""
        property string appId: ""
        property string icon: ""
        property real value: 0
        property real to: 1
        property real step: 0.05
        property bool muted: false
        property real level: 0
        property bool showLevel: true
        signal moved(real value)
        signal muteToggled()

        width: root.contentWidth
        height: 34

        Row {
            anchors.fill: parent
            spacing: Theme.spaceSm

            Item {
                width: Theme.sizeIcon + 4
                height: parent.height

                AppIcon {
                    visible: vr.appId.length > 0
                    anchors.centerIn: parent
                    appId: vr.appId
                    fallbackIcon: "graphic_eq"
                    size: Theme.sizeIcon + 2
                }

                GlyphIcon {
                    visible: vr.appId.length === 0
                    anchors.centerIn: parent
                    icon: vr.icon
                    color: vr.muted ? Theme.textDim : Theme.line
                    animate: true
                }
            }

            Column {
                width: 170
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                GlyphText {
                    width: parent.width
                    text: vr.label
                    dim: vr.muted
                }

                GlyphText {
                    width: parent.width
                    visible: vr.sub.length > 0
                    role: "small"
                    dim: true
                    text: vr.sub
                }
            }

            NomaiSlider {
                anchors.verticalCenter: parent.verticalCenter
                orientation: Qt.Horizontal
                length: root.contentWidth - 170 - (Theme.sizeIcon + 4) - 44 - (vr.showLevel ? 44 : 0) - Theme.spaceSm * (vr.showLevel ? 4 : 3)
                thickness: 22
                value: vr.value
                to: vr.to
                step: vr.step
                muted: vr.muted
                onMoved: v => vr.moved(v)
            }

            LevelBars {
                visible: vr.showLevel
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                level: vr.muted ? 0 : vr.level
                bars: 8
                barHeight: 14
            }

            HexButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                flat: true
                padding: Theme.spaceXs
                icon: vr.muted ? "volume_off" : "volume_up"
                danger: vr.muted
                active: vr.muted
                tooltip: vr.muted ? "Unmute" : "Mute"
                onClicked: vr.muteToggled()
            }
        }
    }
}
