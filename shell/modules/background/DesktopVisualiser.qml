pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.services

// Scene mode (centre): cava bars as a tilted ring around the configured host planet.
// Otherwise: classic bottom-band bars.
Item {
    id: root

    required property ShellScreen screen

    readonly property bool shouldShow: Config.getFor(screen.name, "quantumMoon.background.visualiser.enabled", true) !== false
        && !GameMode.enabled
    readonly property bool isCenter: screen.name === QuantumMoonWallpaper.centerScreenName()
    readonly property bool usePlanetRing: shouldShow && isCenter && QuantumMoonWallpaper.centerUsesScene() && SolarTracker.hasRing
    readonly property real maxFrac: 0.18
    readonly property real baseOpacity: shouldShow ? (usePlanetRing ? 0.85 : 0.65) : 0
    property real snMul: 1

    opacity: baseOpacity * snMul
    visible: opacity > 0.01

    Connections {
        target: SolarTracker
        function onSupernovaActiveChanged(): void {
            if (SolarTracker.supernovaActive)
                snFlicker.restart();
            else {
                snFlicker.stop();
                root.snMul = 1;
            }
        }
    }

    SequentialAnimation {
        id: snFlicker
        running: false
        NumberAnimation { target: root; property: "snMul"; to: 0.15; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "snMul"; to: 0.85; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "snMul"; to: 0.1; duration: 480; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "snMul"; to: 0; duration: 520; easing.type: Easing.InOutSine }
    }

    Component.onCompleted: if (shouldShow) Cava.acquire()
    Component.onDestruction: Cava.release()
    onShouldShowChanged: {
        if (shouldShow)
            Cava.acquire();
        else
            Cava.release();
    }

    // ---- Planet ring (scene wallpaper) ----
    Canvas {
        id: ringCanvas
        anchors.fill: parent
        visible: root.usePlanetRing && !cavaHold
        antialiasing: true

        // Smoothed ring geometry + bar heights (raw solar/cava updates are jumpy).
        property real smCx: 0
        property real smCy: 0
        property real smRx: 40
        property real smTilt: 0.55
        property var smVals: []
        property bool smReady: false
        property string smBody: ""
        readonly property bool cavaHold: SolarTracker.data?.cava_hold === true

        onCavaHoldChanged: {
            if (!cavaHold)
                smReady = false;
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (!visible) {
                smReady = false;
                smBody = "";
            }
        }

        Timer {
            interval: 16
            running: ringCanvas.visible
            repeat: true
            onTriggered: {
                const ring = SolarTracker.activeRing;
                if (!ring || !root.usePlanetRing)
                    return;
                const body = SolarTracker.activeBodyId;
                const tx = Number(ring.x) || 0;
                const ty = Number(ring.y) || 0;
                // Start bars a bit outside the exported ring / planet limb.
                const tr = Math.max(8, (Number(ring.r_px) || 40) * 1.18);
                const tt = Math.max(0.25, Math.min(1.0, Number(ring.tilt) || 0.55));
                const handoff = body !== ringCanvas.smBody || !ringCanvas.smReady;
                if (handoff) {
                    ringCanvas.smBody = body;
                    ringCanvas.smCx = tx;
                    ringCanvas.smCy = ty;
                    ringCanvas.smRx = tr;
                    ringCanvas.smTilt = tt;
                } else {
                    // solar.json steps in about every 80ms. A tight follow copies each step as a shake.
                    const posA = 0.12;
                    const sizeA = 0.06;
                    ringCanvas.smCx += (tx - ringCanvas.smCx) * posA;
                    ringCanvas.smCy += (ty - ringCanvas.smCy) * posA;
                    ringCanvas.smRx += (tr - ringCanvas.smRx) * sizeA;
                    ringCanvas.smTilt += (tt - ringCanvas.smTilt) * sizeA;
                }
                const barA = ringCanvas.smReady ? 0.55 : 1;

                const raw = Cava.values;
                const n = Math.max(1, raw.length);
                const prev = ringCanvas.smVals;
                const next = [];
                for (let i = 0; i < n; i++) {
                    const target = Math.min(1, Math.max(0, Number(raw[i]) || 0));
                    const cur = Number(prev[i]) || 0;
                    next.push(cur + (target - cur) * barA);
                }
                ringCanvas.smVals = next;
                ringCanvas.smReady = true;
                ringCanvas.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root.usePlanetRing || !smReady)
                return;
            const cx = smCx;
            const cy = smCy;
            const rx = Math.max(8, smRx);
            const ry = rx * smTilt;
            const vals = smVals;
            const n = Math.max(1, vals.length);
            const barMax = Math.max(10, rx * 0.22);
            const barW = Math.max(2.0, (2 * Math.PI * rx) / n * 0.55);

            for (let i = 0; i < n; i++) {
                const t = (i / n) * Math.PI * 2 - Math.PI * 0.5;
                const cos = Math.cos(t);
                const sin = Math.sin(t);
                const ex = cx + rx * cos;
                const ey = cy + ry * sin;
                let nx = cos / rx;
                let ny = sin / ry;
                const nlen = Math.hypot(nx, ny) || 1;
                nx /= nlen;
                ny /= nlen;

                const v = Math.min(1, Math.max(0, Number(vals[i]) || 0));
                const len = Math.max(2, barMax * v);
                const accent = Theme.accents[i % Theme.accents.length];
                const col = Theme.alpha(accent, 0.35 + v * 0.55);

                ctx.save();
                ctx.translate(ex, ey);
                ctx.rotate(Math.atan2(ny, nx));
                ctx.fillStyle = col;
                ctx.fillRect(0, -barW * 0.5, len, barW);
                ctx.restore();
            }
        }
    }

    // ---- Bottom band (video mode / side monitors) ----
    Item {
        id: band
        visible: root.shouldShow && !root.usePlanetRing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * root.maxFrac
        anchors.leftMargin: Theme.spaceXl + (Screens.isEnabled("bar", root.screen.name) ? (Config.bar.width ?? 40) : 0)
        anchors.rightMargin: Theme.spaceXl
        anchors.bottomMargin: Theme.spaceLg

        Row {
            id: row
            anchors.fill: parent
            spacing: 1

            Repeater {
                model: Cava.values

                Rectangle {
                    required property int index
                    required property real modelData
                    readonly property real h: Math.max(2, parent.height * Math.min(1, modelData))

                    width: Math.max(2, (row.width - row.spacing * Math.max(0, Cava.values.length - 1)) / Math.max(1, Cava.values.length))
                    height: h
                    anchors.bottom: parent.bottom
                    color: Theme.alpha(Theme.accents[index % Theme.accents.length], 0.4 + modelData * 0.45)

                    Behavior on height {
                        NumberAnimation { duration: 50 }
                    }
                }
            }
        }
    }

    Behavior on opacity {
        enabled: !root.usePlanetRing
        NumberAnimation { duration: Motion.normal; easing.type: Motion.fade }
    }
}
