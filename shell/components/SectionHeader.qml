import QtQuick
import qs.theme

// Zigzag divider + uppercase label header.
Row {
    id: root

    property string text: ""
    spacing: Theme.spaceSm

    NomaiDivider {
        anchors.verticalCenter: parent.verticalCenter
    }

    GlyphText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        role: "label"
        dim: true
    }
}
