import QtQuick
import qs.theme
import qs.components
import qs.services

// Session menu toggle.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    ends: "left"
    connector: false
    active: root.bar?.visibilities?.session ?? false
    lineColor: active ? Theme.danger : Theme.line
    onClicked: Visibilities.toggle("session", root.bar?.visibilities ?? null)

    GlyphIcon {
        icon: "power_settings_new"
        weight: 500
        color: root.active ? Theme.danger : (root.hovered ? Theme.text : Theme.textDim)
        animate: true
        anchors.verticalCenter: parent.verticalCenter
    }
}
