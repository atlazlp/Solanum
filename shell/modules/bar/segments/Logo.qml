import QtQuick
import qs.theme
import qs.components
import qs.services

// Current planet logo. Click toggles the Solanum panel.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    ends: "bottom"
    padding: 2
    active: root.bar?.visibilities?.quantumMoon ?? false
    lineColor: Theme.line
    property string tooltipText: QuantumMoon.displayName

    onClicked: Visibilities.toggle("quantumMoon", root.bar?.visibilities ?? null)

    Item {
        // Nearly fill the ~40 px bar (padding 2×2); was capped at 28.
        implicitWidth: 34
        implicitHeight: implicitWidth

        Image {
            id: img
            visible: status === Image.Ready
            source: QuantumMoon.logoPath ? "file://" + QuantumMoon.logoPath : ""
            anchors.centerIn: parent
            width: parent.width
            height: width
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
        }

        GlyphIcon {
            visible: !img.visible
            icon: "brightness_3"
            size: Math.max(Theme.sizeIcon, parent.implicitWidth * 0.7)
            fill: 1
            color: Theme.ember
            anchors.centerIn: parent
        }
    }

    NomaiTooltip {
        text: root.tooltipText
        show: root.hovered && text !== ""
        place: "right"
        gap: Theme.spaceSm
    }
}
