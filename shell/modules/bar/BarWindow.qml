import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Top bar window (namespace quantum-moon-bar). Reserves Config.bar.height unless DevFlags.dev.
PanelWindow {
    id: root

    readonly property bool enabled: Screens.isEnabled("bar", screen.name)
    readonly property bool hasFullscreen: Hypr.hasFullscreenOn(screen)
    readonly property bool shown: enabled && !(hasFullscreen && !Config.general.showOverFullscreen) && !KvmCapture.active

    visible: shown
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Config.bar.height ?? 36
    exclusiveZone: DevFlags.barExclusive ? implicitHeight : 0
    exclusionMode: DevFlags.barExclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "quantum-moon-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Bar {
        anchors.fill: parent
        screen: root.screen
    }
}
