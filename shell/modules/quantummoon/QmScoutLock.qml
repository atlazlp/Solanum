import QtQuick
import QtQuick.Shapes
import qs.config
import qs.theme
import qs.components
import qs.services
import "../../theme/Glyphs.js" as Glyphs

// Scout lock: a 40 px hex showing the scout; when the planet is locked it widens to a 16:9 bar
// (280 ms InOutQuad) with the locked planet thumbnail (30 px) and a 6 px marker at lockMarkerX/Y.
Item {
    id: root

    readonly property real size: QuantumMoon.lockMarkerBarHeight
    readonly property real barWidth: QuantumMoon.lockMarkerBarWidth
    readonly property real thumbSize: QuantumMoon.lockMarkerThumbSize
    readonly property real markerSize: QuantumMoon.lockMarkerSize
    readonly property bool locked: QuantumMoon.planetLocked
    readonly property string scoutSource: `${Paths.assets}/qm/scout-lq.png`
    readonly property bool markerValid: QuantumMoon.isLockMarkerPlacementValid(QuantumMoon.lockMarkerX, QuantumMoon.lockMarkerY, barWidth, size)

    width: locked ? barWidth : size
    height: size

    Behavior on width {
        NumberAnimation {
            duration: 280
            easing.type: Easing.InOutQuad
        }
    }

    Connections {
        target: QuantumMoon

        function onPlanetLockedChanged() {
            if (!QuantumMoon.planetLocked)
                return;
            if (!QuantumMoon.isLockMarkerPlacementValid(QuantumMoon.lockMarkerX, QuantumMoon.lockMarkerY, root.barWidth, root.size)) {
                QuantumMoon.rollLockMarker(root.barWidth, root.size);
                QuantumMoon.persistLockState();
            }
        }
    }

    NomaiFrame {
        anchors.fill: parent
        shape: "chamfer"
        chamfer: Theme.chamferSm
        fill: hover.hovered ? Theme.ink2 : Theme.alpha(Theme.ink0, 0.75)
        lineColor: Theme.moon
        lineOpacity: root.locked || hover.hovered ? 1 : 0.55
        glow: root.locked
        padding: 0

        Image {
            anchors.fill: parent
            anchors.margins: 3
            visible: !root.locked
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            source: "file://" + root.scoutSource
            opacity: hover.hovered ? 1 : 0.85
        }

        Image {
            width: root.thumbSize
            height: root.thumbSize
            anchors.centerIn: parent
            visible: root.locked && QuantumMoon.lockedSlug.length > 0
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            source: QuantumMoon.lockedSlug.length ? `file://${Paths.assets}/qm/${QuantumMoon.lockedSlug}/logo.png` : ""
        }

        // Scout marker: a hexagonal pip at the persisted offset.
        Shape {
            x: QuantumMoon.lockMarkerX
            y: QuantumMoon.lockMarkerY
            width: root.markerSize
            height: root.markerSize
            visible: root.locked && QuantumMoon.lockedSlug.length > 0 && root.markerValid
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.moon
                strokeColor: Theme.moon
                strokeWidth: 1
                PathSvg { path: Glyphs.hexPip(root.markerSize * 0.5, root.markerSize * 0.5, root.markerSize * 0.5) }
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            if (QuantumMoon.planetLocked)
                QuantumMoon.releaseLock();
            else if (QuantumMoon.slug.length)
                QuantumMoon.engageLock(QuantumMoon.slug, root.barWidth, root.size);
        }
    }

    NomaiTooltip {
        text: root.locked ? "Scout lock engaged: click to release" : "Lock the current planet"
        show: hover.hovered
        align: "end"
    }
}
