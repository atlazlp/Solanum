import QtQuick
import QtQuick.Shapes
import qs.theme

// A link between two ship-log nodes: 1 px lineDim stroke + soft glow, dashed for rumors.
// `progress` draws the line in from `from` to `to` (animated 0 -> 1 on creation, 260 ms).
Shape {
    id: root

    property point from: Qt.point(0, 0)
    property point to: Qt.point(0, 0)
    property bool rumor: false
    property bool highlighted: false
    property bool dimmed: false
    property color color: highlighted ? Theme.line : Theme.lineDim
    property real progress: 0
    property bool animateIn: true

    readonly property real ex: from.x + (to.x - from.x) * progress
    readonly property real ey: from.y + (to.y - from.y) * progress

    preferredRendererType: Shape.CurveRenderer
    opacity: dimmed ? 0.2 : 1
    z: 0

    Behavior on opacity {
        NumberAnimation { duration: Motion.normal; easing.type: Motion.fade }
    }

    Component.onCompleted: {
        if (animateIn)
            drawIn.start();
        else
            progress = 1;
    }

    NumberAnimation {
        id: drawIn
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Motion.slow
        easing.type: Motion.enter
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.alpha(root.color, root.highlighted ? 0.3 : 0.14)
        strokeWidth: 4
        capStyle: ShapePath.FlatCap
        startX: root.from.x
        startY: root.from.y
        PathLine { x: root.ex; y: root.ey }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.highlighted ? 1.5 : 1
        capStyle: ShapePath.FlatCap
        strokeStyle: root.rumor ? ShapePath.DashLine : ShapePath.SolidLine
        dashPattern: [4, 4]
        startX: root.from.x
        startY: root.from.y
        PathLine { x: root.ex; y: root.ey }
    }
}
