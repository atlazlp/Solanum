import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Left bar window (namespace solanum-bar). Reserves Config.bar.width unless DevFlags.dev.
// Window is wider than the exclusive zone so tooltips can paint to the right of the chrome;
// the input mask keeps clicks outside the chrome click-through.
PanelWindow {
    id: root

    readonly property bool enabled: Screens.isEnabled("bar", screen.name)
    readonly property bool hasFullscreen: Hypr.hasFullscreenOn(screen)
    readonly property bool shown: enabled && !(hasFullscreen && !Config.general.showOverFullscreen) && !KvmCapture.active
    readonly property int barWidth: Config.bar.width ?? 40
    readonly property int paintOverflow: 280

    visible: shown
    anchors.left: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: barWidth + paintOverflow
    exclusiveZone: DevFlags.barExclusive ? barWidth : 0
    exclusionMode: DevFlags.barExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "solanum-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: chrome
    }

    Bar {
        id: chrome
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.barWidth
        screen: root.screen
    }
}
