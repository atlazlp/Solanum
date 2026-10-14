import QtQuick
import qs.theme

// Chamfered track with a sliding hex knob.
Item {
    id: root

    property bool checked: false
    property string label: ""
    signal toggled(bool checked)

    implicitWidth: row.implicitWidth
    implicitHeight: 22

    Row {
        id: row
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        NomaiFrame {
            id: track
            width: 40
            height: 22
            padding: 0
            chamfer: Theme.chamferSm
            fill: root.checked ? Theme.alpha(Theme.line, 0.18) : Theme.ink0
            lineColor: root.checked ? Theme.line : Theme.lineDim
            glow: root.checked

            NomaiFrame {
                id: knob
                width: 16
                height: 16
                shape: "hex"
                padding: 0
                fill: root.checked ? Theme.line : Theme.ink3
                lineColor: root.checked ? Theme.line : Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? track.width - width - 3 : 3

                Behavior on x {
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.enter }
                }
            }
        }

        GlyphText {
            visible: root.label !== ""
            text: root.label
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    TapHandler {
        onTapped: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
