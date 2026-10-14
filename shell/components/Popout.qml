import QtQuick
import qs.theme

// Container for a bar popout: chamfered frame with a 1 px stem up to the segment it hangs from.
// `anchorCenterX` is in the popout's parent coordinates; the host positions the popout.
NomaiFrame {
    id: root

    property real anchorCenterX: width / 2
    property int stemHeight: Theme.spaceSm

    padding: Theme.spaceMd
    chamfer: Theme.chamferMd
    fill: Theme.ink1
    glow: true
    ticks: true
    z: Theme.zPopout

    Rectangle {
        parent: root
        x: Math.max(2, Math.min(root.width - 3, root.anchorCenterX - root.x)) - 0.5
        y: -root.stemHeight
        width: 1
        height: root.stemHeight
        color: Theme.line
    }
}
