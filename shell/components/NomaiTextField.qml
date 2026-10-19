import QtQuick
import qs.theme

// Single-line input inside a chamfered frame.
NomaiFrame {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    readonly property bool focused: input.activeFocus

    signal accepted()
    signal escaped()

    padding: Theme.spaceSm
    chamfer: Theme.chamferSm
    fill: Theme.ink0
    lineOpacity: focused ? 1 : 0.6
    glow: focused
    ticks: true
    implicitWidth: 240
    implicitHeight: Math.max(32, input.implicitHeight + padding * 2)

    function forceFocus(): void {
        input.forceActiveFocus();
    }

    Row {
        anchors.fill: parent
        spacing: Theme.spaceSm

        GlyphIcon {
            visible: root.icon !== ""
            icon: root.icon
            color: Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
            id: input
            width: parent.width - (root.icon !== "" ? Theme.sizeIcon * 1.6 + parent.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.family: Theme.fontBody
            font.pointSize: Theme.sizeBody
            selectionColor: Theme.alpha(Theme.line, 0.4)
            selectedTextColor: Theme.text
            clip: true
            onAccepted: root.accepted()
            Keys.onEscapePressed: event => {
                root.escaped();
                event.accepted = true;
            }

            GlyphText {
                visible: input.text.length === 0 && root.placeholder !== ""
                text: root.placeholder
                dim: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
