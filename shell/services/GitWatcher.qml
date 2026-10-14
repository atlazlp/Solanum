pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// STUB (Phase 2 step 8 replaces this): Azure DevOps PR watcher state for the bar status glyph.
Singleton {
    id: root

    property bool configured: false
    property bool active: false
    property int count: 0
    property int overdueCount: 0
    property int mentionCount: 0

    function refresh(): void {
        console.log("GitWatcher: stub refresh()");
    }

    IpcHandler {
        target: "git"

        function refresh(): void {
            root.refresh();
        }

        function open(): void {
            console.log("GitWatcher: stub open()");
        }
    }
}
