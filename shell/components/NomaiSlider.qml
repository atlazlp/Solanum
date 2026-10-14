import QtQuick
import qs.theme

// Chamfered slider. Vertical by default (OSD); set orientation: Qt.Horizontal for panels.
// `moved(value)` fires on drag/click/wheel; the caller sets the real value back into `value`.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05
    property int orientation: Qt.Vertical
    property string icon: ""
    property bool muted: false
    property int thickness: 36
    property int length: 140
    property color accent: Theme.line
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property bool vertical: orientation === Qt.Vertical
    property bool dragging: drag.active

    signal moved(real value)

    implicitWidth: vertical ? thickness : length
    implicitHeight: vertical ? length : thickness

    function valueAt(px: real, py: real): real {
        const r = vertical ? 1 - (py / height) : px / width;
        return from + Math.max(0, Math.min(1, r)) * (to - from);
    }

    NomaiFrame {
        id: track
        anchors.fill: parent
        padding: 0
        chamfer: Theme.chamferSm
        fill: Theme.ink0
        lineColor: root.accent
        lineOpacity: hover.hovered || root.dragging ? 1 : 0.6
        glow: root.dragging
        ticks: true

        // Fill portion
        Item {
            anchors.fill: parent
            anchors.margins: 2
            clip: true

            Rectangle {
                width: root.vertical ? parent.width : parent.width * root.ratio
                height: root.vertical ? parent.height * root.ratio : parent.height
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: root.muted ? Theme.alpha(Theme.lineDim, 0.5) : Theme.alpha(root.accent, 0.28)

                Behavior on height {
                    enabled: !root.dragging
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.enter }
                }
                Behavior on width {
                    enabled: !root.dragging
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.enter }
                }

                // Edge line
                Rectangle {
                    width: root.vertical ? parent.width : 1
                    height: root.vertical ? 1 : parent.height
                    anchors.top: root.vertical ? parent.top : undefined
                    anchors.right: root.vertical ? undefined : parent.right
                    color: root.muted ? Theme.lineDim : root.accent
                }
            }
        }

        GlyphIcon {
            visible: root.icon !== ""
            icon: root.icon
            fill: 1
            size: Theme.sizeIcon
            color: root.muted ? Theme.textDim : Theme.text
            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            anchors.bottom: root.vertical ? parent.bottom : undefined
            anchors.bottomMargin: Theme.spaceSm
            anchors.left: root.vertical ? undefined : parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        }

        GlyphText {
            text: Math.round(root.ratio * 100)
            role: "label"
            dim: true
            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            anchors.top: root.vertical ? parent.top : undefined
            anchors.topMargin: Theme.spaceSm
            anchors.right: root.vertical ? undefined : parent.right
            anchors.rightMargin: Theme.spaceSm
            anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
    }

    DragHandler {
        id: drag
        target: null
        onCentroidChanged: {
            if (active)
                root.moved(root.valueAt(centroid.position.x, centroid.position.y));
        }
    }

    TapHandler {
        onTapped: point => root.moved(root.valueAt(point.position.x, point.position.y))
    }

    WheelHandler {
        onWheel: event => {
            const dir = event.angleDelta.y > 0 ? 1 : (event.angleDelta.y < 0 ? -1 : 0);
            if (dir !== 0)
                root.moved(Math.max(root.from, Math.min(root.to, root.value + dir * root.step)));
        }
    }
}
