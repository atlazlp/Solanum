import QtQuick
import qs.theme

// Centred chamfered dialog over a scrim. `open` shows it; Escape or scrim click emits dismissed().
Item {
    id: root

    default property alias content: frame.content
    property bool open: false
    property string title: ""
    property int padding: Theme.spaceLg
    property bool dismissOnScrim: true

    signal dismissed()

    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1 : 0
    z: Theme.zModal

    Behavior on opacity {
        NumberAnimation { duration: open ? Motion.panelOpen : Motion.panelClose; easing.type: open ? Motion.enter : Motion.exit }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        TapHandler {
            enabled: root.dismissOnScrim
            onTapped: root.dismissed()
        }
    }

    Keys.onEscapePressed: root.dismissed()

    NomaiFrame {
        id: frame
        anchors.centerIn: parent
        padding: root.padding
        chamfer: Theme.chamferLg
        fill: Theme.ink1
        glow: true
        ticks: true
        scale: root.open ? 1 : 0.98

        Behavior on scale {
            NumberAnimation { duration: Motion.panelOpen; easing.type: Motion.enter }
        }
    }

    SectionHeader {
        visible: root.title !== ""
        text: root.title
        anchors.left: frame.left
        anchors.bottom: frame.top
        anchors.bottomMargin: Theme.spaceSm
    }
}
