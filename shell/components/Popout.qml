import QtQuick
import qs.theme

// Container for a bar popout: chamfered frame with a 1 px stem pointing left toward the bar.
// `anchorCenterY` is in the popout's parent coordinates; the host positions the popout.
NomaiFrame {
    id: root

    property real anchorCenterY: height / 2
    property int stemHeight: Theme.spaceSm

    padding: Theme.spaceMd
    chamfer: Theme.chamferMd
    fill: Theme.ink1
    glow: true
    ticks: true
    z: Theme.zPopout

    Rectangle {
        parent: root
        x: -root.stemHeight
        y: Math.max(2, Math.min(root.height - 3, root.anchorCenterY - root.y)) - 0.5
        width: root.stemHeight
        height: 1
        color: Theme.line
    }
}
