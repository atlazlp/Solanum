pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Sun-hover arming prompt: hex "!" (session confirm style) + Outer Wilds–flavoured label.
Item {
    id: root

    readonly property alias hitTarget: row
    readonly property var sun: SolarTracker.sunBody
    readonly property bool sunOk: !!(sun && sun.visible)
    readonly property real sunX: Number(sun?.x) || 0
    readonly property real sunY: Number(sun?.y) || 0
    readonly property real sunR: Math.max(24, Number(sun?.r_px) || 40)

    property bool linger: false
    readonly property bool wantShow: QuantumMoonWallpaper.centerUsesScene()
        && sunOk
        && !SolarTracker.supernovaActive
        && (SolarTracker.sunHovered || linger || btn.hovered)

    visible: wantShow
    opacity: wantShow ? 1 : 0
    z: 5

    Timer {
        id: lingerTimer
        interval: 900
        onTriggered: root.linger = false
    }

    Connections {
        target: SolarTracker
        function onSunHoveredChanged(): void {
            if (SolarTracker.sunHovered) {
                root.linger = true;
                lingerTimer.stop();
            } else if (!btn.hovered) {
                lingerTimer.restart();
            }
        }
    }

    Row {
        id: row
        x: Math.max(Theme.spaceMd, Math.min(root.width - implicitWidth - Theme.spaceMd, root.sunX + root.sunR + Theme.spaceMd))
        y: Math.max(Theme.spaceMd, Math.min(root.height - implicitHeight - Theme.spaceMd, root.sunY - implicitHeight * 0.5))
        spacing: Theme.spaceMd

        HexButton {
            id: btn
            width: 64
            height: Theme.hexHeight(64)
            icon: "priority_high"
            iconSize: 28
            shape: "hex"
            danger: true
            glow: true
            accent: Theme.ember
            tooltip: ""
            onHoveredChanged: {
                if (hovered) {
                    root.linger = true;
                    lingerTimer.stop();
                } else if (!SolarTracker.sunHovered) {
                    lingerTimer.restart();
                }
            }
            onClicked: SolarTracker.triggerSupernova()
        }

        NomaiFrame {
            anchors.verticalCenter: parent.verticalCenter
            padding: Theme.spaceSm
            chamfer: Theme.chamferSm
            fill: Theme.alpha(Theme.ink1, 0.92)
            glow: true
            lineColor: Theme.ember

            GlyphText {
                text: "SCIENCE COMPELS US TO EXPLODE THE SUN"
                role: "small"
                color: Theme.ember
                font.letterSpacing: Theme.letterSpacingHeader
                font.bold: true
            }
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Motion.normal; easing.type: Motion.fade }
    }
}
