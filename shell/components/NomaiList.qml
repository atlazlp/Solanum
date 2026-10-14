import QtQuick
import qs.theme

// ListView with a chamfered highlight and keyboard navigation (Up/Down/Home/End, Return -> activated(index)).
ListView {
    id: root

    signal activated(int index)

    clip: true
    spacing: 2
    keyNavigationEnabled: true
    keyNavigationWraps: true
    highlightMoveDuration: Motion.fast
    highlightResizeDuration: 0
    boundsBehavior: Flickable.StopAtBounds

    highlight: NomaiFrame {
        padding: 0
        chamfer: Theme.chamferSm
        fill: Theme.alpha(Theme.line, 0.12)
        lineColor: Theme.line
        lineOpacity: root.activeFocus ? 1 : 0.6
        glow: root.activeFocus
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (currentIndex >= 0)
                root.activated(currentIndex);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            currentIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            currentIndex = count - 1;
            event.accepted = true;
        }
    }
}
