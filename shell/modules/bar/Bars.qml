pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// One bar window per output (only shown where Screens.isEnabled("bar", name)).
Scope {
    Variants {
        model: Quickshell.screens

        BarWindow {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
