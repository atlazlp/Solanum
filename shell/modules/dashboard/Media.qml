pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs.theme
import qs.components
import qs.services

// Now playing: chamfered art, title/artist, progress arc, controls and a level meter.
Column {
    id: root

    readonly property MprisPlayer player: Players.active
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property string artUrl: Players.getArtUrl(player)
    readonly property int artSize: 120

    function fmt(s: real): string {
        s = Math.max(0, Math.floor(s));
        const m = Math.floor(s / 60);
        const sec = s % 60;
        return `${m}:${sec < 10 ? "0" : ""}${sec}`;
    }

    spacing: Theme.spaceMd
    width: 240

    // Keep the position fresh while playing (Mpris only pushes it on demand).
    Timer {
        running: root.playing && root.player !== null
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Item {
        id: artWrap

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.artSize + 24
        height: root.artSize + 24

        ProgressArc {
            anchors.fill: parent
            value: root.progress
            startAngle: -210
            sweep: 240
            thickness: 3
            accent: root.playing ? Theme.line : Theme.lineDim
            Behavior on value { NumberAnimation { duration: Motion.slow; easing.type: Motion.enter } }
        }

        // Chamfered mask for the art
        Shape {
            id: artMask
            anchors.centerIn: parent
            width: root.artSize
            height: root.artSize
            visible: false
            layer.enabled: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "black"
                strokeWidth: 0
                PathSvg { path: Glyphs.chamferRect(root.artSize, root.artSize, Theme.chamferLg, 5, 0) }
            }
        }

        Item {
            id: art
            anchors.centerIn: parent
            width: root.artSize
            height: root.artSize
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: artMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.ink2
            }

            GlyphIcon {
                anchors.centerIn: parent
                icon: "music_note"
                size: 48
                color: Theme.lineDim
                visible: cover.status !== Image.Ready
            }

            Image {
                id: cover
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: root.artSize * 2
                sourceSize.height: root.artSize * 2
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.normal; easing.type: Motion.fade } }
            }
        }

        // Outline + ticks on the art
        Shape {
            anchors.centerIn: parent
            width: root.artSize
            height: root.artSize
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.alpha(Theme.line, root.playing ? 0.9 : 0.4)
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                PathSvg { path: Glyphs.chamferRect(root.artSize, root.artSize, Theme.chamferLg, 5, 0.5) }
            }
        }

        GlyphText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            role: "mono"
            font.pointSize: Theme.sizeLabel
            text: root.player ? `${root.fmt(root.position)} / ${root.fmt(root.length)}` : "--:-- / --:--"
            color: Theme.textDim
        }
    }

    Column {
        width: parent.width
        spacing: 2

        GlyphText {
            width: parent.width
            role: "large"
            text: root.player?.trackTitle || (root.player ? "Unknown title" : "Nothing playing")
            color: Theme.text
            horizontalAlignment: Text.AlignHCenter
            font.weight: Font.Medium
            animate: true
        }

        GlyphText {
            width: parent.width
            role: "small"
            text: root.player?.trackArtist || (root.player?.identity ?? "")
            dim: true
            horizontalAlignment: Text.AlignHCenter
            animate: true
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceSm

        HexButton {
            icon: "skip_previous"
            shape: "hex"
            flat: true
            enabled: root.player?.canGoPrevious ?? false
            onClicked: Players.previous()
        }

        HexButton {
            icon: root.playing ? "pause" : "play_arrow"
            shape: "hex"
            glow: root.playing
            active: root.playing
            padding: Theme.spaceMd
            enabled: root.player?.canTogglePlaying ?? false
            onClicked: Players.playPause()
        }

        HexButton {
            icon: "skip_next"
            shape: "hex"
            flat: true
            enabled: root.player?.canGoNext ?? false
            onClicked: Players.next()
        }
    }

    LevelBars {
        anchors.horizontalCenter: parent.horizontalCenter
        bars: 16
        barWidth: 4
        barHeight: 12
        level: root.playing ? Audio.peak : 0
        accent: Theme.line
    }

    // Player switcher when several are around
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceXs
        visible: Players.list.length > 1

        Repeater {
            model: Players.list

            HexButton {
                required property MprisPlayer modelData
                icon: "radio"
                text: modelData.identity
                flat: true
                padding: Theme.spaceXs
                iconSize: Theme.sizeSmall + 2
                maxWidth: 90
                active: modelData === root.player
                onClicked: Players.manualActive = modelData
            }
        }
    }
}
