import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.components
import qs.services

// Full lock UI: one-shot screencopy of the screen, blurred + scrimmed, with a 1040x560 NomaiFrame
// (left: weather / fetch / media, centre: clock + password, right: resources / notifications).
// Used by LockSurface (main screen) and by LockPreview (`lock preview` IPC).
Item {
    id: root

    required property var pam
    property var screen: null
    property bool unlocking: false
    property bool preview: false

    readonly property real frameWidth: Math.min(1040, width - Theme.spaceXl * 4)
    readonly property real frameHeight: Math.min(560, height - Theme.spaceXl * 4)
    readonly property real sideWidth: Math.round(frameWidth * 0.27)

    function enter(): void {
        enterAnim.restart();
        reveal.trigger();
    }

    Component.onCompleted: Qt.callLater(enter)

    ScreencopyView {
        id: capture

        anchors.fill: parent
        captureSource: root.screen
        live: false
        paintCursor: false
        visible: root.screen !== null

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: Config.get("lock.blur", 48)
            blurMultiplier: 1
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, Config.get("lock.scrim", 0.45))
        visible: capture.hasContent
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.ink0
        visible: !capture.hasContent
    }

    Item {
        id: fader

        anchors.fill: parent
        opacity: root.unlocking ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Motion.fade }
        }

        NomaiFrame {
            id: frame

            anchors.centerIn: parent
            width: root.frameWidth
            height: root.frameHeight
            fill: Theme.alpha(Theme.ink1, 0.97)
            glow: true
            ticks: true
            chamfer: Theme.chamferLg
            padding: Theme.spaceXl
            scale: 0.96
            opacity: 0

            GlyphReveal {
                id: reveal

                anchors.fill: parent
                autoTrigger: false
                direction: -1

                Column {
                    id: leftCol

                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.sideWidth
                    spacing: Theme.spaceMd

                    LockWeather {
                        id: weather
                        width: parent.width
                    }

                    LockFetch {
                        width: parent.width
                        height: leftCol.height - weather.height - media.height - leftCol.spacing * 2
                    }

                    LockMedia {
                        id: media
                        width: parent.width
                    }
                }

                LockCenter {
                    id: centre

                    pam: root.pam
                    anchors.left: leftCol.right
                    anchors.right: rightCol.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.spaceXl
                    anchors.rightMargin: Theme.spaceXl
                }

                Column {
                    id: rightCol

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.sideWidth
                    spacing: Theme.spaceMd

                    LockResources {
                        id: resources
                        width: parent.width
                    }

                    LockNotifs {
                        width: parent.width
                        height: rightCol.height - resources.height - rightCol.spacing
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            target: frame
            property: "scale"
            from: 0.96
            to: 1
            duration: 320
            easing.type: Motion.enter
        }
        NumberAnimation {
            target: frame
            property: "opacity"
            from: 0
            to: 1
            duration: 320
            easing.type: Motion.fade
        }
    }
}
