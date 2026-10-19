import QtQuick
import QtQuick.Shapes
import qs.theme
import "../theme/Glyphs.js" as Glyphs

// Chamfered (or hexagonal) frame: ink fill, 1 px line, optional 6 px outer glow and corner ticks.
// Children are laid out inside `anchors.margins: padding` of the frame via the `content` item.
Item {
    id: root

    default property alias content: inner.data

    property string shape: "chamfer"   // "chamfer" | "hex"
    property color fill: Theme.ink1
    property color lineColor: Theme.line
    property real lineWidth: Theme.lineWidth
    property real lineOpacity: 1
    property int chamfer: Theme.chamferMd
    property int corners: 5             // bitmask: 1 tl, 2 tr, 4 br, 8 bl
    property bool glow: false
    property real glowOpacity: 0.18
    property bool ticks: false
    property int padding: Theme.spaceMd
    property real hexCut: -1

    readonly property real inset: lineWidth / 2
    readonly property string pathData: shape === "hex" ? Glyphs.hexagon(width, height, hexCut < 0 ? undefined : hexCut, inset) : Glyphs.chamferRect(width, height, chamfer, corners, inset)

    // Regular flat-top hex: width = height × 2/√3 so every side is the same length.
    implicitWidth: {
        const w = inner.implicitWidth + padding * 2;
        const h = inner.implicitHeight + padding * 2;
        if (shape !== "hex")
            return w;
        const side = Math.max(w / Theme.hexAspect, h);
        return side * Theme.hexAspect;
    }
    implicitHeight: {
        const w = inner.implicitWidth + padding * 2;
        const h = inner.implicitHeight + padding * 2;
        if (shape !== "hex")
            return h;
        return Math.max(w / Theme.hexAspect, h);
    }

    Shape {
        id: glowShape

        anchors.fill: parent
        visible: root.glow && root.glowOpacity > 0
        preferredRendererType: Shape.CurveRenderer
        opacity: root.glowOpacity

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.lineColor
            strokeWidth: Theme.glowWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            PathSvg { path: root.pathData }
        }
    }

    Shape {
        id: body

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fill
            strokeColor: root.lineWidth > 0 ? Theme.alpha(root.lineColor, root.lineOpacity) : "transparent"
            strokeWidth: Math.max(root.lineWidth, 0.01)
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: root.pathData }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.ticks && root.shape === "chamfer"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.lineColor
            strokeWidth: Theme.tickWidth
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.BevelJoin
            PathSvg { path: Glyphs.cornerTicks(root.width, root.height, Theme.tickLength, root.inset) }
        }
    }

    Item {
        id: inner

        anchors.fill: parent
        anchors.margins: root.padding
        implicitWidth: {
            let w = 0;
            for (const c of children)
                if (c.visible !== false)
                    w = Math.max(w, c.implicitWidth);
            return w;
        }
        implicitHeight: {
            let h = 0;
            for (const c of children)
                if (c.visible !== false)
                    h = Math.max(h, c.implicitHeight);
            return h;
        }
    }

    Behavior on fill {
        ColorAnimation {
            duration: Motion.fast
            easing.type: Motion.fade
        }
    }

    Behavior on lineOpacity {
        NumberAnimation {
            duration: Motion.fast
            easing.type: Motion.fade
        }
    }
}
