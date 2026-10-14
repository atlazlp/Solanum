pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services

// Right drawer (360 px, full height): DND / clear / ship-log header, compact media card,
// quick toggles and the grouped notification list.
Item {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    implicitWidth: 360
    implicitHeight: 720

    function reveal(): void {
        revealer.trigger();
    }

    NomaiFrame {
        anchors.fill: parent
        anchors.topMargin: Theme.spaceSm
        anchors.bottomMargin: Theme.spaceSm
        anchors.rightMargin: Theme.spaceSm
        padding: Theme.spaceMd
        chamfer: Theme.chamferLg
        corners: 9     // tl + bl: the frame hugs the right edge
        fill: Theme.ink1
        glow: true
        ticks: true

        GlyphReveal {
            id: revealer
            anchors.fill: parent
            autoTrigger: false

            Column {
                id: layout
                anchors.fill: parent
                spacing: Theme.spaceMd

                // ---- header ----
                Item {
                    width: parent.width
                    height: 32

                    GlyphText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Signals"
                        role: "title"
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spaceSm

                        NomaiSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "DND"
                            checked: Notifs.dnd
                            onToggled: c => Notifs.dnd = c
                        }

                        HexButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "clear_all"
                            flat: true
                            tooltip: "Clear all"
                            enabled: Notifs.count > 0
                            onClicked: Notifs.clear()
                        }

                        HexButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "hub"
                            text: "Ship log"
                            glow: ShipLog.unreadCount > 0
                            tooltip: ShipLog.unreadCount > 0 ? `${ShipLog.unreadCount} unread` : "Open ship-log"
                            onClicked: Visibilities.open("shipLog", root.visibilities)
                        }
                    }
                }

                NomaiDivider {
                    width: parent.width
                    segments: 7
                }

                // ---- media ----
                NomaiFrame {
                    id: media
                    readonly property var player: Players.active
                    width: parent.width
                    visible: player !== null
                    padding: Theme.spaceSm
                    chamfer: Theme.chamferSm
                    fill: Theme.ink0
                    lineOpacity: 0.5
                    implicitHeight: 52 + padding * 2

                    Row {
                        anchors.fill: parent
                        spacing: Theme.spaceSm

                        NomaiFrame {
                            width: 52
                            height: 52
                            padding: 0
                            chamfer: Theme.chamferSm
                            fill: Theme.ink2
                            lineOpacity: 0.6

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: media.player ? Players.getArtUrl(media.player) : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(104, 104)
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            GlyphIcon {
                                anchors.centerIn: parent
                                icon: "music_note"
                                color: Theme.textDim
                                visible: !(media.player && Players.getArtUrl(media.player))
                            }
                        }

                        Column {
                            width: parent.width - 52 - controls.width - parent.spacing * 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            GlyphText {
                                text: media.player?.trackTitle || "Nothing playing"
                                role: "body"
                                font.weight: Font.Medium
                                width: parent.width
                            }

                            GlyphText {
                                text: media.player?.trackArtist || media.player?.identity || ""
                                role: "small"
                                dim: true
                                width: parent.width
                            }
                        }

                        Row {
                            id: controls
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            HexButton {
                                icon: "skip_previous"
                                flat: true
                                padding: 3
                                onClicked: Players.previous()
                            }
                            HexButton {
                                icon: media.player?.isPlaying ? "pause" : "play_arrow"
                                shape: "hex"
                                padding: 4
                                active: media.player?.isPlaying ?? false
                                onClicked: Players.playPause()
                            }
                            HexButton {
                                icon: "skip_next"
                                flat: true
                                padding: 3
                                onClicked: Players.next()
                            }
                        }
                    }
                }

                // ---- quick toggles ----
                Row {
                    width: parent.width
                    spacing: Theme.spaceSm

                    HexButton {
                        icon: "coffee"
                        text: "Keep awake"
                        active: IdleInhibitor.enabled
                        padding: Theme.spaceSm
                        tooltip: "Idle inhibitor"
                        onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
                    }

                    HexButton {
                        icon: "nightlight"
                        text: "Night light"
                        active: NightLight.enabled
                        padding: Theme.spaceSm
                        onClicked: NightLight.toggle()
                    }

                    HexButton {
                        icon: "screen_record"
                        text: Recorder.running ? (Recorder.paused ? "Paused" : "REC") : "Idle"
                        active: Recorder.running
                        danger: Recorder.running && !Recorder.paused
                        padding: Theme.spaceSm
                        tooltip: Recorder.running ? "Recording in progress" : "Recorder idle"

                        SequentialAnimation on opacity {
                            running: Recorder.running && !Recorder.paused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 700; easing.type: Motion.fade }
                            NumberAnimation { to: 1; duration: 700; easing.type: Motion.fade }
                            onStopped: parent.opacity = 1
                        }
                    }
                }

                // ---- notifications ----
                Item {
                    width: parent.width
                    height: 20

                    SectionHeader {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                    }

                    GlyphText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.count > 0 ? `${Notifs.count}` : (Notifs.dnd ? "quiet" : "clear")
                        role: "label"
                        dim: true
                    }
                }

                Flickable {
                    id: list
                    width: parent.width
                    height: layout.height - y
                    contentHeight: groups.implicitHeight
                    contentWidth: width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 4000

                    Column {
                        id: groups
                        width: list.width
                        spacing: Theme.spaceMd

                        move: Transition {
                            NumberAnimation { properties: "y"; duration: Motion.normal; easing.type: Motion.enter }
                        }

                        Repeater {
                            model: Notifs.groups

                            NotifGroup {
                                required property var modelData
                                group: modelData
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: Notifs.count === 0
                        spacing: Theme.spaceSm

                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: Notifs.dnd ? "do_not_disturb_on" : "notifications_off"
                            color: Theme.lineDim
                            size: 36
                        }

                        GlyphText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Notifs.dnd ? "Quiet. Signals go to the ship log." : "No new signals"
                            role: "small"
                            dim: true
                        }
                    }
                }
            }
        }
    }
}
