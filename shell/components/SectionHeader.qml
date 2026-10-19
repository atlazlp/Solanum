import QtQuick
import qs.theme

// Zigzag divider + uppercase label header.
Row {
    id: root

    property string text: ""
    property bool filterHidden: false
    spacing: Theme.spaceSm

    states: State {
        name: "filtered"
        when: root.filterHidden
        PropertyChanges {
            root.visible: false
            root.height: 0
        }
    }

    NomaiDivider {
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.spark
    }

    GlyphText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        role: "label"
        color: Theme.spark
        opacity: 0.9
    }
}
