import QtQuick
import QtQuick.Shapes
import qs.theme
import "../../theme/Glyphs.js" as Glyphs

// Protractor arc (top half-circle) with a major tick at every planet index and a minor tick between.
// Planet i sits at theta_i = -pi + pi * i / (count - 1) (0 = +x, clockwise) on radius `radius`.
Shape {
    id: root

    property real cx: 0
    property real cy: 0
    property real radius: 106
    property int count: 5
    property color color: Theme.line
    property real majorTick: 10
    property real minorTick: 4

    readonly property string arcPath: Glyphs.arc(cx, cy, radius, -Math.PI, 0)
    readonly property string tickPath: {
        let d = "";
        const span = Math.max(1, count - 1);
        const steps = span * 2;
        for (let s = 0; s <= steps; s++) {
            const th = -Math.PI + Math.PI * s / steps;
            const len = s % 2 === 0 ? majorTick : minorTick;
            const r0 = radius - len * 0.5, r1 = radius + len * 0.5;
            d += " M " + (cx + r0 * Math.cos(th)).toFixed(2) + " " + (cy + r0 * Math.sin(th)).toFixed(2)
               + " L " + (cx + r1 * Math.cos(th)).toFixed(2) + " " + (cy + r1 * Math.sin(th)).toFixed(2);
        }
        return d.trim();
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.alpha(root.color, 0.18)
        strokeWidth: Theme.glowWidth
        capStyle: ShapePath.FlatCap
        PathSvg { path: root.arcPath }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.alpha(root.color, 0.55)
        strokeWidth: Theme.lineWidth
        capStyle: ShapePath.FlatCap
        PathSvg { path: root.arcPath }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.alpha(root.color, 0.8)
        strokeWidth: Theme.lineWidth
        capStyle: ShapePath.FlatCap
        PathSvg { path: root.tickPath }
    }
}
