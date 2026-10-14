pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Lives in the drawers window directly under the bar. Bar segments call
// show(name, absX, width, data, sticky) with the segment's absolute x on the screen; the popout
// is centred under it. Hover popouts hide shortly after the pointer leaves both; sticky ones
// (click-opened menus) stay until hide(), Escape or a long pointer absence.
Item {
    id: root

    required property ShellScreen screen
    readonly property alias frame: frame

    property string currentName: ""
    property bool hasCurrent: false
    property bool sticky: false
    property real anchorX: 0
    property real anchorWidth: 0
    property var payload: null   // (never name this `data`: it would shadow Item.data and orphan the children)
    readonly property bool hovered: hover.hovered

    height: hasCurrent ? frame.implicitHeight + Theme.spaceSm : 0
    z: Theme.zPopout

    Component.onCompleted: Visibilities.registerPopout(screen.name, this)

    function show(name: string, absX: real, w: real, payloadValue: var, stickyOpen: bool): void {
        hideTimer.stop();
        currentName = name;
        anchorX = absX;
        anchorWidth = w;
        root.payload = payloadValue ?? null;
        sticky = !!stickyOpen;
        hasCurrent = true;
    }

    function hide(): void {
        hideTimer.stop();
        hasCurrent = false;
        sticky = false;
        payload = null;
    }

    function scheduleHide(): void {
        if (!hasCurrent)
            return;
        hideTimer.interval = sticky ? 900 : 250;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        onTriggered: {
            if (!root.hovered)
                root.hide();
            else
                restart();
        }
    }

    Connections {
        target: KvmCapture
        function onActiveChanged(): void {
            if (KvmCapture.active)
                root.hide();
        }
    }

    Popout {
        id: frame

        readonly property real desiredX: root.anchorX + root.anchorWidth / 2 - width / 2
        x: Math.max(Theme.spaceSm, Math.min(root.width - width - Theme.spaceSm, desiredX))
        y: Theme.spaceSm
        anchorCenterX: root.anchorX + root.anchorWidth / 2
        visible: root.hasCurrent
        opacity: root.hasCurrent ? 1 : 0
        implicitWidth: loader.item?.implicitWidth ?? 0
        implicitHeight: loader.item?.implicitHeight ?? 0
        width: implicitWidth + padding * 2
        height: implicitHeight + padding * 2

        Behavior on opacity {
            NumberAnimation { duration: Motion.fast; easing.type: Motion.fade }
        }

        Keys.onEscapePressed: root.hide()

        Loader {
            id: loader
            active: root.hasCurrent
            sourceComponent: {
                switch (root.currentName) {
                case "audio": return audioComp;
                case "network": return networkComp;
                case "tray": return trayComp;
                case "activewindow": return activeWindowComp;
                }
                return null;
            }
            onLoaded: {
                if (item && "host" in item)
                    item.host = root;
            }
        }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (!hovered)
                    root.scheduleHide();
                else
                    hideTimer.stop();
            }
        }
    }

    Component { id: audioComp; AudioPopout {} }
    Component { id: networkComp; NetworkPopout {} }
    Component { id: trayComp; TrayMenu {} }
    Component { id: activeWindowComp; ActiveWindowPopout {} }
}
