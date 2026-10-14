pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.services
import qs.modules.osd
import qs.modules.bar.popouts

// Full-screen transparent layer (namespace quantum-moon-drawers). Only the regions listed in
// Regions.qml take input; everything else passes through to the apps below.
PanelWindow {
    id: root

    readonly property alias visibilities: visibilities
    readonly property alias panels: panels
    readonly property bool barEnabled: Screens.isEnabled("bar", screen.name)
    readonly property int barHeight: barEnabled ? (Config.bar.height ?? 36) : 0
    readonly property bool hasFullscreen: Hypr.hasFullscreenOn(screen)
    readonly property bool suppressed: hasFullscreen && !Config.general.showOverFullscreen

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "quantum-moon-drawers"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visibilities.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Regions {
        panels: panels
        strips: strips
        toasts: toasts
        popouts: popouts
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
        id: content

        anchors.fill: parent
        anchors.topMargin: root.barHeight
        focus: true

        Keys.onEscapePressed: visibilities.closeAll()

        Panels {
            id: panels
            anchors.fill: parent
            screen: root.screen
            visibilities: visibilities
        }

        PopoutHost {
            id: popouts
            screen: root.screen
            anchors.top: parent.top
            width: parent.width
        }

        HoverStrips {
            id: strips
            anchors.fill: parent
            screen: root.screen
            visibilities: visibilities
            panels: panels
        }

        Toasts {
            id: toasts
            screen: root.screen
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spaceLg
        }
    }

    OsdWatcher {
        screen: root.screen
        visibilities: visibilities
        panels: panels
    }
}
