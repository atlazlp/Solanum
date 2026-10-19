import QtQuick
import qs.theme
import qs.components
import qs.services

// Stacked time + date for the left bar. Click toggles the dashboard.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    padding: Theme.spaceXs
    active: root.bar?.visibilities?.dashboard ?? false
    onClicked: Visibilities.toggle("dashboard", root.bar?.visibilities ?? null)

    Column {
        spacing: 0
        anchors.horizontalCenter: parent.horizontalCenter

        GlyphText {
            text: Time.format("HH")
            role: "title"
            font.pointSize: Theme.sizeBody + 1
            color: root.active ? Theme.spark : Theme.text
            anchors.horizontalCenter: parent.horizontalCenter
        }

        GlyphText {
            text: Time.format("mm")
            role: "title"
            font.pointSize: Theme.sizeBody + 1
            color: root.active ? Theme.spark : Theme.text
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item { width: 1; height: 3 }

        NomaiDivider {
            width: Math.max(14, parent.width * 0.65)
            segments: 3
            color: Theme.spark
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item { width: 1; height: 2 }

        GlyphText {
            text: Time.format("ddd").toLowerCase()
            role: "label"
            font.pointSize: Theme.sizeLabel
            color: Theme.spark
            opacity: 0.85
            anchors.horizontalCenter: parent.horizontalCenter
        }

        GlyphText {
            text: Time.format("MMM").toLowerCase()
            role: "label"
            font.pointSize: Theme.sizeLabel
            color: Theme.secondary
            opacity: 0.9
            anchors.horizontalCenter: parent.horizontalCenter
        }

        GlyphText {
            text: Time.format("d")
            role: "label"
            font.pointSize: Theme.sizeLabel
            color: Theme.spark
            opacity: 0.85
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
