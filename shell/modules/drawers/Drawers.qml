pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// One transparent full-screen drawers window per output.
Scope {
    Variants {
        model: Quickshell.screens

        DrawerWindow {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
