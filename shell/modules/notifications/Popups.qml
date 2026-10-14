pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.services

// Popup stack: top-right under the bar (the "notifications" panel slot). Shows Notifs.popups;
// the slot itself opens while Notifs.popupCount > 0 and no sidebar is open.
Item {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    implicitWidth: 380 + Theme.spaceMd * 2
    implicitHeight: column.implicitHeight + Theme.spaceMd * 2

    Column {
        id: column

        x: Theme.spaceMd
        y: Theme.spaceMd
        width: 380
        spacing: Theme.spaceSm

        move: Transition {
            NumberAnimation { properties: "y"; duration: Motion.normal; easing.type: Motion.enter }
        }

        Repeater {
            model: Notifs.popups

            Popup {}
        }
    }
}
