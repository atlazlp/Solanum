pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// STUB (Phase 2 step 5 replaces this with the NotificationServer): counts and DND for the bar/sidebar.
Singleton {
    id: root

    property bool dnd: false
    property int count: 0
    property list<var> list: []

    function clear(): void {
        console.log("Notifs: stub clear()");
        list = [];
        count = 0;
    }

    IpcHandler {
        target: "notifs"

        function clear(): void {
            root.clear();
        }

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }

        function enableDnd(): void {
            root.dnd = true;
        }

        function disableDnd(): void {
            root.dnd = false;
        }

        function isDndEnabled(): bool {
            return root.dnd;
        }
    }
}
