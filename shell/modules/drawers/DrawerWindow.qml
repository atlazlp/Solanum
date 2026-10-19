pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.services
import qs.modules.osd
import qs.modules.bar.popouts

// Full-screen transparent layer (namespace solanum-drawers). Only the regions listed in
// Regions.qml take input; everything else passes through to the apps below.
PanelWindow {
    id: root

    readonly property alias visibilities: visibilities
    readonly property alias panels: panels
    readonly property alias strips: strips
    readonly property bool barEnabled: Screens.isEnabled("bar", screen.name)
    readonly property int barWidth: barEnabled ? (Config.bar.width ?? 40) : 0
    readonly property bool hasFullscreen: Hypr.hasFullscreenOn(screen)
    readonly property bool suppressed: hasFullscreen && !Config.general.showOverFullscreen
    readonly property bool anyDismissable: visibilities.anyOpen() || popouts.hasCurrent

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "solanum-drawers"
    WlrLayershell.layer: WlrLayer.Top
    // Exclusive grabs keyboard so Super-opened launcher can receive typing immediately.
    WlrLayershell.keyboardFocus: visibilities.wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Regions {
        panels: panels
        strips: strips
        toasts: toasts
        popouts: popouts
        dismiss: dismissCatcher
    }

    DrawerVisibilities {
        id: visibilities
        Component.onCompleted: Visibilities.load(root.screen, this)
    }

    onSuppressedChanged: {
        if (suppressed)
            visibilities.closeAll();
    }

    Item {
        id: stripsHost

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (popouts.hasCurrent)
                popouts.hide();
            else
                visibilities.closeAll();
        }

        HoverStrips {
            id: strips
            anchors.fill: parent
            screen: root.screen
            visibilities: visibilities
            panels: panels
        }

        Item {
            id: content

            anchors.fill: parent
            anchors.leftMargin: root.barWidth

            // Full-area click-away: closes sticky popouts and manually opened drawers.
            // Hover-opened drawers stay on the hover-leave timer (still closed if you click away).
            // Ignore taps that land on a panel slot so ship-log nodes / buttons don't dismiss.
            Item {
                id: dismissCatcher

                anchors.fill: parent
                z: 0
                visible: root.anyDismissable

                function pointOnPanel(sx: real, sy: real): bool {
                    for (const slot of panels.slots) {
                        if (!slot?.visible || (slot.opacity ?? 1) < 0.01)
                            continue;
                        const p = slot.mapFromItem(content, sx, sy);
                        if (p.x >= 0 && p.y >= 0 && p.x < slot.width && p.y < slot.height)
                            return true;
                    }
                    if (popouts.hasCurrent && popouts.frame) {
                        const p = popouts.frame.mapFromItem(content, sx, sy);
                        if (p.x >= 0 && p.y >= 0 && p.x < popouts.frame.width && p.y < popouts.frame.height)
                            return true;
                    }
                    return false;
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: (eventPoint, button) => {
                        const pos = eventPoint.position;
                        if (dismissCatcher.pointOnPanel(pos.x, pos.y))
                            return;
                        if (popouts.hasCurrent)
                            popouts.hide();
                        visibilities.closeAll();
                    }
                }
            }

            Panels {
                id: panels
                anchors.fill: parent
                z: 1
                screen: root.screen
                visibilities: visibilities
            }

            PopoutHost {
                id: popouts
                screen: root.screen
                anchors.fill: parent
                z: 2
            }

            Toasts {
                id: toasts
                screen: root.screen
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spaceLg
                z: 3
            }
        }
    }

    OsdWatcher {
        screen: root.screen
        visibilities: visibilities
        panels: panels
    }
}
