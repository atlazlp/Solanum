pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.components
import qs.services

// Background layer per screen (namespace quantum-moon-background): the planet's slot PNG for this
// monitor, below everything. When the centre monitor plays the mpvpaper video the window goes
// transparent on the Bottom layer so the video (Background layer) shows through.
// Optional desktop clock per Config.quantumMoon.background.desktopClock.
Scope {
    Variants {
        model: Quickshell.screens.filter(s => Config.getFor(s.name, "quantumMoon.background.enabled", true) !== false)

        PanelWindow {
            id: win

            required property ShellScreen modelData

            readonly property bool showSlot: QuantumMoonWallpaper.shouldShowOnScreen(modelData.name)
            readonly property var clockCfg: Config.getFor(modelData.name, "quantumMoon.background.desktopClock", ({}))

            screen: modelData
            exclusionMode: ExclusionMode.Ignore
            color: showSlot ? "black" : "transparent"

            WlrLayershell.namespace: "quantum-moon-background"
            WlrLayershell.layer: showSlot ? WlrLayer.Background : WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            mask: Region {}

            Loader {
                anchors.fill: parent
                active: win.showSlot
                asynchronous: true

                sourceComponent: SlotWallpaper {
                    path: QuantumMoonWallpaper.slotPathForScreen(win.modelData.name)
                }
            }

            Loader {
                id: clockLoader

                active: (win.clockCfg?.enabled ?? false) === true && !GameMode.enabled
                anchors.margins: Theme.spaceXl * 2
                anchors.topMargin: Theme.spaceXl * 2 + (Screens.isEnabled("bar", win.modelData.name) ? (Config.bar.height ?? 36) : 0)

                state: win.clockCfg?.position ?? "bottom-right"
                states: [
                    State {
                        name: "top-left"
                        AnchorChanges { target: clockLoader; anchors.top: parent.top; anchors.left: parent.left }
                    },
                    State {
                        name: "top-center"
                        AnchorChanges { target: clockLoader; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter }
                    },
                    State {
                        name: "top-right"
                        AnchorChanges { target: clockLoader; anchors.top: parent.top; anchors.right: parent.right }
                    },
                    State {
                        name: "middle-left"
                        AnchorChanges { target: clockLoader; anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left }
                    },
                    State {
                        name: "middle-center"
                        AnchorChanges { target: clockLoader; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: parent.horizontalCenter }
                    },
                    State {
                        name: "middle-right"
                        AnchorChanges { target: clockLoader; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right }
                    },
                    State {
                        name: "bottom-left"
                        AnchorChanges { target: clockLoader; anchors.bottom: parent.bottom; anchors.left: parent.left }
                    },
                    State {
                        name: "bottom-center"
                        AnchorChanges { target: clockLoader; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
                    },
                    State {
                        name: "bottom-right"
                        AnchorChanges { target: clockLoader; anchors.bottom: parent.bottom; anchors.right: parent.right }
                    }
                ]

                sourceComponent: Column {
                    spacing: Theme.spaceXs

                    GlyphText {
                        role: "display"
                        text: Time.timeStr
                        color: Theme.text
                        style: Text.Outline
                        styleColor: Theme.alpha(Theme.ink0, 0.6)
                        anchors.right: parent.right
                    }

                    Row {
                        spacing: Theme.spaceSm
                        anchors.right: parent.right

                        NomaiDivider {
                            width: 36
                            segments: 3
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        GlyphText {
                            role: "label"
                            text: Time.dateStr.toUpperCase()
                            color: Theme.textDim
                            font.letterSpacing: Theme.letterSpacingHeader
                            style: Text.Outline
                            styleColor: Theme.alpha(Theme.ink0, 0.6)
                        }
                    }
                }
            }
        }
    }
}
