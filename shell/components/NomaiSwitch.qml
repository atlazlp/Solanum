import QtQuick
import qs.theme

// Chamfered track with a sliding hex knob.
Item {
    id: root

    property bool checked: false
    property string label: ""
    signal toggled(bool checked)

    implicitWidth: row.implicitWidth
    implicitHeight: 32
    activeFocusOnTab: true

    function toggle(): void {
        if (!root.enabled)
            return;
        root.checked = !root.checked;
        root.toggled(root.checked);
    }

    Row {
        id: row
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        NomaiFrame {
            id: track
            width: 46
            height: 26
            padding: 0
            chamfer: Theme.chamferSm
            fill: root.checked ? Theme.alpha(Theme.line, 0.18) : Theme.ink0
            lineColor: root.checked || root.activeFocus ? Theme.line : Theme.lineDim
            lineOpacity: root.checked || root.activeFocus || hover.hovered ? 1 : 0.7
            glow: root.checked || root.activeFocus

            NomaiFrame {
                id: knob
                height: 18
                width: Theme.hexWidth(18)
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
        enabled: root.enabled
        onTapped: root.toggle()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggle();
            event.accepted = true;
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
