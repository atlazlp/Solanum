pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services

// Quantum Moon panel (top-right drawer "quantumMoon"): selector wheel ring, five planet logos on a
// 106 px arc, the QM button at the arc centre, Eye mode and the scout lock. Geometry is the
// verbatim port of the Caelestia patch panel; the dressing is Nomai (chamfered frame, arc ticks).
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
    readonly property real selectorWheelSize: btnSize * 5.8

    readonly property real layoutW: arcRadius * 2 + planetSize + hPad * 2
    readonly property real layoutH: vPad * 2 + planetSize * 0.5 + arcRadius + btnSize

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
    // While the wheel spins the frame line drifts toward the destination planet's primary.
    lineColor: QuantumMoon.destinationPrimary.a > 0 ? Theme.mix(Theme.line, QuantumMoon.destinationPrimary, QuantumMoon.spinBlend) : Theme.line

    Component.onCompleted: QuantumMoon.syncWheelRingIfIdle()

    Item {
        id: body

        anchors.fill: parent
        clip: true

        GlyphReveal {
            id: revealer

            anchors.fill: parent
            autoTrigger: false

            // ---- orbit layout (planets on the arc) ----
            Item {
                id: orbitLayout

                anchors.fill: parent
                visible: !root.eyeMode

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

                QmArc {
                    anchors.fill: parent
                    cx: orbitLayout.arcCx
                    cy: orbitLayout.arcCy
                    radius: root.arcRadius
                    count: root.planetSlugs.length
                    color: root.lineColor
                    opacity: root.locked ? 0.4 : 1
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
                        opacity: root.locked ? 0.38 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.normal
                                easing.type: Motion.fade
                            }
                        }

                        NomaiFrame {
                            anchors.fill: parent
                            anchors.margins: 2
                            shape: "hex"
                            fill: planetHover.hovered && !root.locked ? Theme.alpha(Theme.ink2, 0.6) : "transparent"
                            lineColor: planet.pending ? root.lineColor : Theme.line
                            lineOpacity: planet.pending ? 1 : (planetHover.hovered && !root.locked ? 1 : (planet.current ? 0.5 : 0))
                            glow: planet.pending || planet.current
                            glowOpacity: planet.pending ? 0.3 : 0.12
                            padding: 0
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

                // QM button at the arc centre.
                Item {
                    id: qmBtn

                    width: root.btnSize
                    height: root.btnSize
                    x: orbitLayout.arcCx - width * 0.5
                    y: orbitLayout.arcCy - height * 0.5
                    opacity: root.locked ? 0.38 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.normal
                            easing.type: Motion.fade
                        }
                    }

                    NomaiFrame {
                        anchors.fill: parent
                        anchors.margins: -4
                        shape: "hex"
                        fill: qmHover.hovered && !root.locked ? Theme.alpha(Theme.ink2, 0.7) : "transparent"
                        lineOpacity: qmHover.hovered && !root.locked ? 1 : 0
                        glow: qmHover.hovered && !root.locked
                        padding: 0
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

                    NomaiTooltip {
                        text: "Quantum jump: random planet"
                        show: qmHover.hovered
                        anchors.top: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: Theme.spaceXs
                    }
                }
            }

            // ---- Eye mode (eye-of-the-universe): the eye logo replaces the arc ----
            Item {
                id: eyeLayout

                anchors.fill: parent
                visible: root.eyeMode

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

                    NomaiFrame {
                        anchors.fill: parent
                        anchors.margins: -8
                        shape: "hex"
                        fill: eyeHover.hovered && !root.locked ? Theme.alpha(Theme.ink2, 0.7) : "transparent"
                        lineOpacity: eyeHover.hovered && !root.locked ? 1 : 0.35
                        glow: true
                        padding: 0
                    }

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        source: root.logoFor("eye-of-the-universe")
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
                    text: "Quantum Moon"
                }

                GlyphText {
                    role: "small"
                    text: QuantumMoon.pendingApplySlug.length ? "jumping..." : (QuantumMoon.displayName || "no planet")
                    color: QuantumMoon.pendingApplySlug.length ? root.lineColor : Theme.text
                    width: 120
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
        }
    }
}
