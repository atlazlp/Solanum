import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.services

// Debug host for `qs -c solanum ipc call lock preview [seconds]`: shows LockContent inside a
// normal top-layer PanelWindow on the main screen (no WlSessionLock, PAM disabled), then unloads.
PanelWindow {
    id: root

    screen: Screens.mainScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "solanum-lock-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Pam {
        id: previewPam

        enabled: false
    }

    LockContent {
        anchors.fill: parent
        pam: previewPam
        screen: root.screen
        preview: true
    }

    Timer {
        interval: Math.max(1, Lock.previewSeconds) * 1000
        running: true
        onTriggered: Lock.previewActive = false
    }
}
