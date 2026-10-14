import QtQuick
import qs.theme

// Material Symbols Rounded glyph. `fill` 0..1, `weight` 100..700, `size` in points.
Text {
    id: root

    property string icon: ""
    property real fill: 0
    property int weight: 400
    property real size: Theme.sizeIcon
    property bool animate: false

    text: icon
    color: Theme.text
    font.family: Theme.fontIcon
    font.pointSize: size
    font.variableAxes: ({
            "FILL": fill,
            "wght": weight,
            "GRAD": 0,
            "opsz": Math.max(20, Math.min(48, Math.round(size * 1.4)))
        })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on fill {
        enabled: root.animate
        NumberAnimation {
            duration: Motion.fast
            easing.type: Motion.fade
        }
    }

    Behavior on color {
        enabled: root.animate
        ColorAnimation {
            duration: Motion.normal
            easing.type: Motion.fade
        }
    }
}
