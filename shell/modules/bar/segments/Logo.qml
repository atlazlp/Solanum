import QtQuick
import qs.theme
import qs.components
import qs.services

// Current planet logo (state/current.json -> $QM_ROOT/modes/<slug>/logo.png). Click toggles the Quantum Moon panel.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    ends: "right"
    padding: Theme.spaceSm
    active: root.bar?.visibilities?.quantumMoon ?? false
    lineColor: Theme.ember
    property string tooltipText: QuantumMoon.displayName

    onClicked: Visibilities.toggle("quantumMoon", root.bar?.visibilities ?? null)

    Row {
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        Image {
            id: img
            visible: status === Image.Ready
            source: QuantumMoon.logoPath ? "file://" + QuantumMoon.logoPath : ""
            width: root.height - Theme.spaceSm * 2
            height: width
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
        }

        GlyphIcon {
            visible: !img.visible
            icon: "brightness_3"
            fill: 1
            color: Theme.ember
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    NomaiTooltip {
        text: root.tooltipText
        show: root.hovered && text !== ""
        anchors.top: parent.bottom
        anchors.left: parent.left
        anchors.topMargin: Theme.spaceXs
    }
}
