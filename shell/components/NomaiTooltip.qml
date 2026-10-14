import QtQuick
import qs.theme

// Small chamfered label that appears after `delay` ms while `show` is true.
NomaiFrame {
    id: root

    property string text: ""
    property bool show: false
    property int delay: 500

    visible: opacity > 0
    opacity: shown.running || revealed ? 1 : 0
    property bool revealed: false
    z: Theme.zToast
    padding: Theme.spaceSm
    chamfer: Theme.chamferSm
    fill: Theme.ink0
    lineOpacity: 0.8

    GlyphText {
        text: root.text
        role: "small"
    }

    onShowChanged: {
        if (show)
            shown.restart();
        else {
            shown.stop();
            revealed = false;
        }
    }

    Timer {
        id: shown
        interval: root.delay
        onTriggered: root.revealed = true
    }

    Behavior on opacity {
        NumberAnimation { duration: Motion.fast }
    }
}
