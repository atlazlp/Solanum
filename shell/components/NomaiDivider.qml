import QtQuick
import QtQuick.Shapes
import qs.theme
import "../theme/Glyphs.js" as Glyphs

// 3-segment zigzag divider (precedes section headers).
Item {
    id: root

    property int segments: 3
    property color color: Theme.lineDim
    property real lineOpacity: 1
    property int zigHeight: 6

    implicitWidth: 36
    implicitHeight: zigHeight

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.alpha(root.color, root.lineOpacity)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: Glyphs.zigzag(root.width, root.height, root.segments) }
        }
    }
}
