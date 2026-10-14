pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Per-screen fade-to-black overlay driven by QuantumMoon.overlayOpacity (Overlay layer, never takes input).
// Windows exist only while a planet transition is active (namespace quantum-moon-fade).
Scope {
    LazyLoader {
        active: QuantumMoon.active

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                WlrLayershell.namespace: "quantum-moon-fade"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                mask: Region {}

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: QuantumMoon.overlayOpacity
                }
            }
        }
    }
}
