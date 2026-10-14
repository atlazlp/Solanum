import QtQuick
import qs.theme
import qs.components
import qs.services

// Now playing (Players.active): art, title, artist, previous / play-pause / next.
NomaiFrame {
    id: root

    readonly property var player: Players.active
    readonly property string artUrl: player ? Players.getArtUrl(player) : ""

    padding: Theme.spaceMd
    fill: Theme.alpha(Theme.ink2, 0.9)
    lineOpacity: 0.5
    corners: 8
    implicitHeight: 112

    Row {
        anchors.fill: parent
        spacing: Theme.spaceMd

        NomaiFrame {
            id: artFrame

            width: 64
            height: 64
            anchors.verticalCenter: parent.verticalCenter
            padding: 0
            fill: Theme.ink2
            lineOpacity: 0.5
            chamfer: Theme.chamferSm
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(128, 128)
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Motion.normal; easing.type: Motion.fade }
                }
            }

            GlyphIcon {
                anchors.centerIn: parent
                icon: "music_note"
                size: 26
                color: Theme.textDim
                visible: root.artUrl === ""
            }
        }

        Column {
            width: parent.width - artFrame.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            GlyphText {
                width: parent.width
                role: "label"
                dim: true
                text: root.player ? "Now playing" : "Silence"
            }

            GlyphText {
                width: parent.width
                role: "body"
                text: root.player?.trackTitle || "No media"
            }

            GlyphText {
                width: parent.width
                role: "small"
                dim: true
                text: root.player?.trackArtist || "—"
            }

            Row {
                spacing: Theme.spaceXs
                topPadding: Theme.spaceXs

                HexButton {
                    flat: true
                    icon: "skip_previous"
                    iconSize: 16
                    padding: 4
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player?.previous()
                }

                HexButton {
                    icon: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                    iconSize: 16
                    padding: 4
                    active: root.player?.isPlaying ?? false
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player?.togglePlaying()
                }

                HexButton {
                    flat: true
                    icon: "skip_next"
                    iconSize: 16
                    padding: 4
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player?.next()
                }
            }
        }
    }
}
