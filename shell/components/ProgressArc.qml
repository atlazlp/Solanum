import QtQuick
import QtQuick.Shapes
import qs.theme

// Arc gauge: dim track + accent progress. `value` 0..1.
Item {
    id: root

    property real value: 0
    property real startAngle: -210
    property real sweep: 240
    property real thickness: 3
    property color accent: Theme.line
    property color track: Theme.lineDim
    property bool glow: true

    implicitWidth: 48
    implicitHeight: 48

    readonly property real r: Math.min(width, height) / 2 - thickness

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.thickness
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.r
                radiusY: root.r
                startAngle: root.startAngle
                sweepAngle: root.sweep
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.alpha(root.accent, 0.18)
            strokeWidth: root.thickness + Theme.glowWidth
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.r
                radiusY: root.r
                startAngle: root.startAngle
                sweepAngle: root.glow ? root.sweep * Math.max(0, Math.min(1, root.value)) : 0
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.accent
            strokeWidth: root.thickness
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.r
                radiusY: root.r
                startAngle: root.startAngle
                sweepAngle: root.sweep * Math.max(0, Math.min(1, root.value))

                Behavior on sweepAngle {
                    NumberAnimation { duration: Motion.normal; easing.type: Motion.enter }
                }
            }
        }
    }
}
