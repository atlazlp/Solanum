pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Set by the KVM daemon while the keyboard/mouse are captured by another machine:
// every drawer closes and hover strips are disabled until capture ends.
Singleton {
    id: root

    property bool active: false
    property bool daemon: false
    property bool clipboard: false

    function setActive(on: bool): void {
        if (root.active === on)
            return;
        root.active = on;
        if (on)
            Visibilities.closeAll();
    }

    IpcHandler {
        target: "kvm"

        function capture(on: bool): void {
            root.setActive(on);
        }

        function isCaptured(): bool {
            return root.active;
        }

        function daemon(on: bool): void {
            root.daemon = on;
        }

        function clipboard(on: bool): void {
            root.clipboard = on;
        }
    }
}
