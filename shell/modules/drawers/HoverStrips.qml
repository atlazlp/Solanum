pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// Thin edge zones that open drawers on hover (modules["hover.*"] matrix). Disabled under
// game mode, KVM capture and when the screen has a fullscreen window.
Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property Item panels

    readonly property alias topCentre: topCentre
    readonly property alias topRight: topRight
    readonly property alias bottomCentre: bottomCentre
    readonly property alias rightEdge: rightStrip

    readonly property int thickness: 3
    readonly property bool blocked: GameMode.enabled || KvmCapture.active || Hypr.hasFullscreenOn(screen)
    property var hoverOpened: ({})

    function hoverOpen(name: string): void {
        if (root.visibilities[name])
            return;
        Visibilities.open(name, root.visibilities);
        const next = Object.assign({}, hoverOpened);
        next[name] = true;
        hoverOpened = next;
    }

    function stripFor(name: string): Item {
        switch (name) {
        case "dashboard": return topCentre;
        case "quantumMoon": return topRight;
        case "launcher": return bottomCentre;
        case "sidebar": return rightStrip;
        }
        return null;
    }

    // While something was opened by hover, poll whether the pointer is still over it or its strip.
    Timer {
        interval: 250
        repeat: true
        running: Object.keys(root.hoverOpened).length > 0
        onTriggered: {
            const next = Object.assign({}, root.hoverOpened);
            let changed = false;
            for (const name in next) {
                const slot = root.panels.slotFor(name);
                const strip = root.stripFor(name);
                if (!root.visibilities[name]) {
                    delete next[name];
                    changed = true;
                    continue;
                }
                const over = (slot && slot.hovered) || (strip && strip.hovered);
                if (!over) {
                    root.visibilities[name] = false;
                    delete next[name];
                    changed = true;
                }
            }
            if (changed)
                root.hoverOpened = next;
        }
    }

    Strip {
        id: topCentre
        drawer: "dashboard"
        enabled: !root.blocked && Screens.isEnabled("hover.dashboard", root.screen.name) && Config.getFor(root.screen.name, "dashboard.showOnHover", true) !== false
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width / 3
        height: root.thickness
    }

    Strip {
        id: topRight
        drawer: "quantumMoon"
        enabled: !root.blocked && Screens.isEnabled("hover.quantumMoon", root.screen.name) && Config.quantumMoon.enabled !== false && Config.quantumMoon.showOnHover !== false
        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.width / 5
        height: root.thickness
    }

    Strip {
        id: bottomCentre
        drawer: "launcher"
        enabled: !root.blocked && Screens.isEnabled("hover.launcher", root.screen.name) && Config.getFor(root.screen.name, "launcher.showOnHover", false) === true
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width / 3
        height: root.thickness
    }

    Strip {
        id: rightStrip
        drawer: "sidebar"
        enabled: !root.blocked && Screens.isEnabled("hover.sidebar", root.screen.name) && Config.getFor(root.screen.name, "sidebar.showOnHover", false) === true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.thickness
        height: parent.height / 3
    }

    component Strip: Item {
        id: strip

        required property string drawer
        readonly property alias hovered: hh.hovered
        visible: enabled

        HoverHandler {
            id: hh
            enabled: strip.enabled
            onHoveredChanged: {
                if (hovered)
                    root.hoverOpen(strip.drawer);
            }
        }
    }
}
