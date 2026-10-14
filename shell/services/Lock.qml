pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// STUB (Phase 2 step 7 replaces this with WlSessionLock + Pam): session lock state and IPC.
Singleton {
    id: root

    property bool locked: false

    signal lockRequested()
    signal unlockRequested()

    function lock(): void {
        console.log("Lock: stub lock() (no WlSessionLock yet)");
        lockRequested();
    }

    function unlock(): void {
        console.log("Lock: stub unlock()");
        unlockRequested();
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function unlock(): void {
            root.unlock();
        }

        function isLocked(): bool {
            return root.locked;
        }
    }
}
