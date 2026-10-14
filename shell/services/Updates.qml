pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// STUB (Phase 2 step 9 replaces this): pending package updates.
Singleton {
    id: root

    property int count: 0
    property bool checking: false
    property list<var> packages: []

    function refresh(): void {
        console.log("Updates: stub refresh()");
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh();
        }

        function run(): void {
            console.log("Updates: stub run()");
        }

        function count(): int {
            return root.count;
        }
    }
}
