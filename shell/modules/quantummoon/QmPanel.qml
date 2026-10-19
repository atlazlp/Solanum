pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services

// Solanum planet panel (top-right drawer "quantumMoon"): selector wheel, planet logos on an arc,
// centre jump button, Eye mode and scout lock. No hex frames or arc tick lines on the logos.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property var planetSlugs: QuantumMoon.wheelPlanetSlugs
    readonly property real planetSize: 80
    readonly property real btnSize: 52
    readonly property real arcRadius: 106
    readonly property real eyeLogoSize: 120
    readonly property real hPad: Theme.spaceLg
    readonly property real vPad: Theme.spaceLg
    readonly property real orbitLift: -15
    readonly property real cardHeightTrim: 15
    // Clear band above the wheel so the planet name can use the full header line.
    readonly property real headerBand: Theme.spaceXl + Theme.spaceSm
    readonly property real selectorWheelSize: btnSize * 5.8
    readonly property real scoutLockReserve: locked ? QuantumMoon.lockMarkerBarWidth : QuantumMoon.lockMarkerBarHeight

    readonly property real layoutW: arcRadius * 2 + planetSize + hPad * 2
    readonly property real layoutH: headerBand + vPad * 2 + planetSize * 0.5 + arcRadius + btnSize

    readonly property bool eyeMode: QuantumMoon.slug === "eye-of-the-universe"
    readonly property bool locked: QuantumMoon.planetLocked
    readonly property string qmAssets: `${Paths.assets}/qm`

    function logoFor(slug: string): string {
        return slug.length ? `file://${qmAssets}/${slug}/logo.png` : "";
    }

    function reveal(): void {
        revealer.trigger();
    }

    padding: Theme.spaceSm
    implicitWidth: layoutW + padding * 2
    implicitHeight: layoutH + padding * 2 - cardHeightTrim
    chamfer: Theme.chamferLg
    fill: Theme.ink1
    glow: true
    ticks: true
    lineColor: QuantumMoon.destinationPrimary.a > 0 ? Theme.mix(Theme.line, QuantumMoon.destinationPrimary, QuantumMoon.spinBlend) : Theme.line

    Component.onCompleted: QuantumMoon.syncWheelRingIfIdle()

    Item {
        id: body

        anchors.fill: parent

        GlyphReveal {
            id: revealer

            anchors.fill: parent
            autoTrigger: false

            // ---- orbit layout (planets on the arc) ----
            Item {
                id: orbitLayout

                anchors.fill: parent
                anchors.topMargin: root.headerBand
                visible: !root.eyeMode
                clip: true

                readonly property real arcCx: width * 0.5
                readonly property real arcCy: height - root.vPad - root.btnSize * 0.5 + root.orbitLift

                Image {
                    id: selectorWheel

                    z: -1
                    width: root.selectorWheelSize
                    height: root.selectorWheelSize
                    x: orbitLayout.arcCx - width * 0.5
                    y: orbitLayout.arcCy - height * 0.5
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    source: `file://${root.qmAssets}/SelectorWheel.png`
                    rotation: QuantumMoon.wheelRingDisplayDeg
                    transformOrigin: Item.Center
                    opacity: root.locked ? 0.5 : 0.9

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.normal
                            easing.type: Motion.fade
                        }
                    }
                }

                Repeater {
                    model: root.planetSlugs

                    delegate: Item {
                        id: planet

                        required property string modelData
                        required property int index

                        readonly property string slug: modelData
                        readonly property real span: Math.max(1, root.planetSlugs.length - 1)
                        readonly property real angle: -Math.PI / 2 + (Math.PI * index / span)
                        readonly property bool current: QuantumMoon.slug === slug
                        readonly property bool pending: QuantumMoon.pendingApplySlug === slug

                        width: root.planetSize
                        height: root.planetSize
                        x: orbitLayout.arcCx + root.arcRadius * Math.sin(angle) - root.planetSize * 0.5
                        y: orbitLayout.arcCy - root.arcRadius * Math.cos(angle) - root.planetSize * 0.5
                        opacity: root.locked ? 0.38 : (planetHover.hovered ? 1 : (planet.current || planet.pending ? 1 : 0.85))
                        scale: planetHover.hovered && !root.locked ? 1.06 : (planet.pending ? 1.04 : 1)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.normal
                                easing.type: Motion.fade
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Motion.fast
                                easing.type: Motion.enter
                            }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            source: root.logoFor(planet.slug)
                        }

                        HoverHandler {
                            id: planetHover
                            enabled: !root.locked
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: !root.locked
                            onTapped: QuantumMoon.applyPlanetSlug(planet.slug)
                        }
                    }
                }

                Item {
                    id: qmBtn

                    width: root.btnSize
                    height: root.btnSize
                    x: orbitLayout.arcCx - width * 0.5
                    y: orbitLayout.arcCy - height * 0.5
                    opacity: root.locked ? 0.38 : (qmHover.hovered ? 1 : 0.9)
                    scale: qmHover.hovered && !root.locked ? 1.08 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.normal
                            easing.type: Motion.fade
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.fast
                            easing.type: Motion.enter
                        }
                    }

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        source: `file://${root.qmAssets}/QMWhite.png`
                    }

                    HoverHandler {
                        id: qmHover
                        enabled: !root.locked
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: !root.locked
                        onTapped: QuantumMoon.start()
                    }
                }
            }

            // ---- Eye mode (eye-of-the-universe): the eye logo replaces the arc ----
            Item {
                id: eyeLayout

                anchors.fill: parent
                anchors.topMargin: root.headerBand
                visible: root.eyeMode
                clip: true

                Item {
                    id: eyeBtn

                    width: root.eyeLogoSize
                    height: root.eyeLogoSize
                    anchors.centerIn: parent
                    opacity: root.locked ? 0.38 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.normal
                            easing.type: Motion.fade
                        }
                    }

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        source: root.logoFor("eye-of-the-universe")
                        opacity: eyeHover.hovered && !root.locked ? 1 : 0.9
                    }

                    HoverHandler {
                        id: eyeHover
                        enabled: !root.locked
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: !root.locked
                        onTapped: QuantumMoon.start()
                    }
                }
            }

            // ---- header label (top-left) ----
            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.spaceXs
                spacing: 2

                GlyphText {
                    role: "label"
                    dim: true
                    text: "Solanum"
                }

                GlyphText {
                    role: "small"
                    text: QuantumMoon.pendingApplySlug.length ? "jumping..." : (QuantumMoon.displayName || "no planet")
                    color: QuantumMoon.pendingApplySlug.length ? root.lineColor : Theme.text
                    width: Math.max(160, body.width - root.scoutLockReserve - Theme.spaceLg * 2)
                    elide: Text.ElideRight
                }

                GlyphText {
                    role: "label"
                    dim: true
                    visible: QuantumMoon.queueLength > 0
                    text: `queued ${QuantumMoon.queueLength}`
                }
            }

            // ---- scout lock (top-right) ----
            QmScoutLock {
                z: 10
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spaceXs
            }

            // Outside the clipped orbit so it can paint past the panel bottom.
            NomaiTooltip {
                anchorItem: qmBtn
                text: "Random planet"
                show: qmHover.hovered && orbitLayout.visible
            }
        }
    }
}
