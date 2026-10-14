import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.components
import qs.services

// One surface per screen. The main screen (`modules["lock.fullUi"]`) shows the full LockContent;
// other screens are black with a faint planet logo. Every surface feeds the shared Pam buffer.
WlSessionLockSurface {
    id: root

    required property Pam pam
    required property var host

    readonly property bool fullUi: Screens.isEnabled("lock.fullUi", screen?.name ?? "")
    readonly property bool unlocking: host?.unlocking ?? false

    color: fullUi ? "transparent" : "black"

    Loader {
        anchors.fill: parent
        active: root.fullUi

        sourceComponent: LockContent {
            pam: root.pam
            screen: root.screen
            unlocking: root.unlocking
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.fullUi
        opacity: root.unlocking ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Motion.fast; easing.type: Motion.fade }
        }

        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.28
            height: width
            source: QuantumMoon.logoPath ? `file://${QuantumMoon.logoPath}` : ""
            fillMode: Image.PreserveAspectFit
            opacity: 0.1
            asynchronous: true
            mipmap: true
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spaceXl * 3
            spacing: Theme.spaceSm

            NomaiDivider {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.lineDim
            }

            GlyphText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "label"
                dim: true
                text: root.pam.buffer.length > 0 ? `${root.pam.buffer.length} ·· press Enter` : "press any key"
                opacity: 0.6
            }
        }
    }

    // Keyboard: whichever surface the compositor focuses feeds the shared buffer.
    Item {
        id: keys

        anchors.fill: parent
        focus: true

        onActiveFocusChanged: {
            if (!activeFocus)
                forceActiveFocus();
        }

        Keys.onPressed: event => {
            if (root.unlocking)
                return;
            root.pam.handleKey(event);
            event.accepted = true;
        }

        Component.onCompleted: forceActiveFocus()
    }
}
