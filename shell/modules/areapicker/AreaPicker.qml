pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Per-screen Overlay windows for the screenshot area picker. Driven by the Screenshot singleton:
// `Screenshot.active` loads the windows, `closing` releases input, `capturing` hides the chrome
// so grim captures the real screen (or the frozen ScreencopyView in freeze mode).
Scope {
    id: root

    LazyLoader {
        id: loader

        activeAsync: Screenshot.active

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                color: "transparent"
                WlrLayershell.namespace: "quantum-moon-area-picker"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.keyboardFocus: Screenshot.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
                mask: Screenshot.closing ? empty : null

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Region {
                    id: empty
                }

                Picker {
                    screen: win.modelData
                }
            }
        }
    }
}
