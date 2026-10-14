import QtQuick
import QtQuick.Shapes
import qs.theme
import "../theme/Glyphs.js" as Glyphs

// Bar segment: parallelogram with 30-degree slanted ends and a 1 px connector line to the next segment.
// Put the content inside; width grows with content + slant allowance.
Item {
    id: root

    default property alias content: inner.data

    property string ends: "both"          // both | left | right | none
    property bool connector: true
    property int connectorLength: Theme.spaceSm
    property bool hovered: false
    property bool active: false
    property bool interactive: true
    property color fill: Theme.ink1
    property color lineColor: Theme.line
    property int padding: Theme.spaceMd
    property real lineOpacity: hovered || active ? 1 : 0.6

    readonly property real slant: height * Math.tan(Math.PI / 6)
    readonly property real leftSlant: ends === "both" || ends === "left" ? slant : 0
    readonly property real rightSlant: ends === "both" || ends === "right" ? slant : 0

    signal clicked(var point)
    signal rightClicked(var point)
    signal wheel(var event)
    signal entered()
    signal exited()

    implicitWidth: inner.implicitWidth + padding * 2 + leftSlant + rightSlant
    implicitHeight: inner.implicitHeight + Theme.spaceSm * 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.hovered ? Theme.ink2 : (pressFlash.running ? Theme.alpha(Theme.lineSoft, 0.14) : root.fill)
            strokeColor: Theme.alpha(root.lineColor, root.lineOpacity)
            strokeWidth: Theme.lineWidth
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: Glyphs.slantedSegment(root.width, root.height, root.slant, root.ends, Theme.lineWidth / 2) }

            Behavior on fillColor {
                ColorAnimation { duration: Motion.fast }
            }
            Behavior on strokeColor {
                ColorAnimation { duration: Motion.fast }
            }
        }
    }

    // Connector to the next segment (drawn beyond the right edge; the row spacing must equal connectorLength)
    Rectangle {
        visible: root.connector
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - root.rightSlant / 2
        width: root.connectorLength + root.rightSlant / 2
        height: 1
        color: Theme.alpha(root.lineColor, 0.6)
    }

    Item {
        id: inner

        anchors.fill: parent
        anchors.leftMargin: root.leftSlant + root.padding
        anchors.rightMargin: root.rightSlant + root.padding
        anchors.topMargin: Theme.spaceSm
        anchors.bottomMargin: Theme.spaceSm
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
