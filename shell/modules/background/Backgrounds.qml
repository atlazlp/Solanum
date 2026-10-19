pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.components
import qs.services

// Background layer per screen (namespace solanum-background): the planet's slot PNG for this
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

            WlrLayershell.namespace: "solanum-background"
            WlrLayershell.layer: showSlot ? WlrLayer.Background : WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // Pass-through except the sun prompt, planet right-click discs, and an open orbit menu.
            mask: inputMask

            Region {
                id: inputMask
                Region { item: sunPromptLoader.item?.wantShow ? sunPromptLoader.item.hitTarget : null }
                Region { item: planetMenuLoader.item?.hitTwins?.onScreen ? planetMenuLoader.item.hitTwins : null }
                Region { item: planetMenuLoader.item?.hitTimber?.onScreen ? planetMenuLoader.item.hitTimber : null }
                Region { item: planetMenuLoader.item?.hitBrittle?.onScreen ? planetMenuLoader.item.hitBrittle : null }
                Region { item: planetMenuLoader.item?.hitGiants?.onScreen ? planetMenuLoader.item.hitGiants : null }
                Region { item: planetMenuLoader.item?.hitBramble?.onScreen ? planetMenuLoader.item.hitBramble : null }
                Region { item: planetMenuLoader.item?.videoMode ? planetMenuLoader.item.videoHit : null }
                Region { item: planetMenuLoader.item?.menuOpen ? planetMenuLoader.item.dismiss : null }
                Region { item: planetMenuLoader.item?.menuOpen ? planetMenuLoader.item.menuBox : null }
            }

            Loader {
                anchors.fill: parent
                active: win.showSlot
                asynchronous: true

                sourceComponent: SlotWallpaper {
                    path: QuantumMoonWallpaper.slotPathForScreen(win.modelData.name)
                }
            }

            Loader {
                anchors.fill: parent
                active: Config.getFor(win.modelData.name, "quantumMoon.background.visualiser.enabled", true) !== false && !GameMode.enabled
                asynchronous: true
                z: 1

                sourceComponent: DesktopVisualiser {
                    screen: win.modelData
                }
            }

            Loader {
                id: sunPromptLoader
                anchors.fill: parent
                active: !win.showSlot && QuantumMoonWallpaper.centerUsesScene()
                    && win.modelData.name === QuantumMoonWallpaper.centerScreenName()
                asynchronous: true
                z: 4

                sourceComponent: SunSupernovaPrompt {}
            }

            Loader {
                id: planetMenuLoader
                anchors.fill: parent
                active: !win.showSlot && win.modelData.name === QuantumMoonWallpaper.centerScreenName()
                    && (QuantumMoonWallpaper.centerUsesScene()
                        || (QuantumMoonWallpaper.centerUsesVideo() && SolarTracker.planetVideoBody.length > 0))
                asynchronous: true
                z: 5

                sourceComponent: PlanetOrbitMenu {}
            }

            Loader {
                id: clockLoader

                active: (win.clockCfg?.enabled ?? false) === true && !GameMode.enabled
                z: 2
                // Pull in from the corner a bit more than the old flush placement.
                anchors.margins: Theme.spaceXl * 3.25
                anchors.leftMargin: Theme.spaceXl * 3.25 + (Screens.isEnabled("bar", win.modelData.name) ? (Config.bar.width ?? 40) : 0)

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
                    spacing: Theme.spaceSm

                    Row {
                        spacing: 2
                        anchors.right: parent.right

                        GlyphText {
                            text: Time.format("HH")
                            font.family: Theme.fontDisplay
                            font.pointSize: Theme.sizeDisplay * 2.35
                            font.weight: Font.Medium
                            // Planet primary (was white Theme.text).
                            color: Theme.line
                            style: Text.Outline
                            styleColor: Theme.alpha(Theme.ink0, 0.7)
                        }

                        GlyphText {
                            text: ":"
                            font.family: Theme.fontDisplay
                            font.pointSize: Theme.sizeDisplay * 2.35
                            font.weight: Font.DemiBold
                            color: Theme.spark
                            style: Text.Outline
                            styleColor: Theme.alpha(Theme.ink0, 0.7)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        GlyphText {
                            text: Time.format("mm")
                            font.family: Theme.fontDisplay
                            font.pointSize: Theme.sizeDisplay * 2.35
                            font.weight: Font.Medium
                            color: Theme.secondary
                            style: Text.Outline
                            styleColor: Theme.alpha(Theme.ink0, 0.7)
                        }
                    }

                    Row {
                        spacing: Theme.spaceSm
                        anchors.right: parent.right

                        NomaiDivider {
                            width: 56
                            segments: 3
                            color: Theme.line
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        GlyphText {
                            role: "small"
                            text: Time.dateStr.toUpperCase()
                            color: Theme.line
                            font.letterSpacing: Theme.letterSpacingHeader
                            font.pointSize: Theme.sizeBody + 1
                            style: Text.Outline
                            styleColor: Theme.alpha(Theme.ink0, 0.65)
                            opacity: 0.95
                        }
                    }
                }
            }
        }
    }
}
