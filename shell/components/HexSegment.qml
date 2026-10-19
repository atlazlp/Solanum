import QtQuick
import QtQuick.Shapes
import qs.theme
import "../theme/Glyphs.js" as Glyphs

// Bar segment: parallelogram with 30-degree slanted ends and a 1 px connector line to the next segment.
// Horizontal: left/right slants, connector to the right. Vertical: top/bottom slants, connector below.
Item {
    id: root

    default property alias content: inner.data

    property bool vertical: true
    property string ends: "both"          // horizontal: both|left|right|none; vertical: both|top|bottom|none
    property bool connector: true
    property int connectorLength: Theme.spaceSm
    property bool hovered: false
    property bool active: false
    property bool interactive: true
    property color fill: Theme.ink1
    property color lineColor: active ? Theme.spark : Theme.line
    property int padding: Theme.spaceMd
    property real lineOpacity: hovered || active ? 1 : 0.6
    // Compact bar mode: tighter padding / icon rhythm for tray + status.
    property bool compact: false
    // Small filled triangles on the sharp corners; slanted corners get a soft radius instead.
    property bool ticks: true
    property real cornerRadius: 3.5
    property real cornerFill: Theme.tickLength + 1

    readonly property real slant: vertical
        ? width * Math.tan(Math.PI / 6)
        : height * Math.tan(Math.PI / 6)
    readonly property real startSlant: {
        if (vertical)
            return ends === "both" || ends === "top" ? slant : 0;
        return ends === "both" || ends === "left" ? slant : 0;
    }
    readonly property real endSlant: {
        if (vertical)
            return ends === "both" || ends === "bottom" ? slant : 0;
        return ends === "both" || ends === "right" ? slant : 0;
    }
    // Compat aliases used by a few segments that still read left/right slant.
    readonly property real leftSlant: vertical ? 0 : startSlant
    readonly property real rightSlant: vertical ? 0 : endSlant

    signal clicked(var point)
    signal rightClicked(var point)
    signal wheel(var event)
    signal entered()
    signal exited()

    implicitWidth: vertical
        ? inner.implicitWidth + padding * 2
        : inner.implicitWidth + padding * 2 + startSlant + endSlant
    implicitHeight: vertical
        ? inner.implicitHeight + padding * 2 + startSlant + endSlant
        : inner.implicitHeight + Theme.spaceSm * 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.hovered ? Theme.ink2 : (pressFlash.running ? Theme.alpha(Theme.lineSoft, 0.14) : root.fill)
            strokeColor: Theme.alpha(root.lineColor, root.lineOpacity)
            strokeWidth: Theme.lineWidth
            joinStyle: ShapePath.MiterJoin
            PathSvg {
                path: root.vertical
                    ? Glyphs.slantedSegmentVertical(root.width, root.height, root.slant, root.ends, Theme.lineWidth / 2, root.cornerRadius)
                    : Glyphs.slantedSegment(root.width, root.height, root.slant, root.ends, Theme.lineWidth / 2)
            }

            Behavior on fillColor {
                ColorAnimation { duration: Motion.fast }
            }
            Behavior on strokeColor {
                ColorAnimation { duration: Motion.fast }
            }
        }
    }

    Rectangle {
        visible: root.connector
        color: Theme.alpha(root.lineColor, 0.6)
        width: root.vertical ? 1 : root.connectorLength + root.endSlant / 2
        height: root.vertical ? root.connectorLength + root.endSlant / 2 : 1
        x: root.vertical ? root.width / 2 - 0.5 : root.width - root.endSlant / 2
        y: root.vertical ? root.height - root.endSlant / 2 : root.height / 2 - 0.5
    }

    Shape {
        anchors.fill: parent
        visible: root.ticks
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.92

        ShapePath {
            fillColor: root.lineColor
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg {
                // Inset matches the body stroke so fills stay inside the segment outline.
                path: root.vertical
                    ? Glyphs.cornerFillsVertical(root.width, root.height, root.slant, root.ends, root.cornerFill, Theme.lineWidth / 2)
                    : Glyphs.cornerTicks(root.width, root.height, Theme.tickLength, 1)
            }
        }
    }

    Item {
        id: inner

        anchors.fill: parent
        anchors.leftMargin: root.vertical ? root.padding : root.startSlant + root.padding
        anchors.rightMargin: root.vertical ? root.padding : root.endSlant + root.padding
        anchors.topMargin: root.vertical ? root.startSlant + root.padding : Theme.spaceSm
        anchors.bottomMargin: root.vertical ? root.endSlant + root.padding : Theme.spaceSm
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

    HoverHandler {
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            root.hovered = hovered;
            if (hovered)
                root.entered();
            else
                root.exited();
        }
    }

    TapHandler {
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (point, button) => {
            pressFlash.restart();
            if (button === Qt.RightButton)
                root.rightClicked(point);
            else
                root.clicked(point);
        }
    }

    WheelHandler {
        enabled: root.interactive
        onWheel: event => root.wheel(event)
    }

    Timer {
        id: pressFlash
        interval: Motion.press
    }
}
