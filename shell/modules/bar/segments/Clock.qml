import QtQuick
import qs.theme
import qs.components
import qs.services

// HH:mm in the display font + short date. Click toggles the dashboard.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    active: root.bar?.visibilities?.dashboard ?? false
    onClicked: Visibilities.toggle("dashboard", root.bar?.visibilities ?? null)

    Row {
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        GlyphText {
            text: Time.timeStr
            role: "title"
            font.pointSize: Theme.sizeLarge
            color: root.active ? Theme.line : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }

        NomaiDivider {
            width: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        GlyphText {
            text: Time.dateStr
            role: "small"
            dim: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
