pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// STUB (Phase 2 step 8 replaces this): gpu-screen-recorder control.
Singleton {
    id: root

    property bool running: false
    property bool paused: false
    property string mode: ""

    IpcHandler {
        target: "record"

        function start(mode: string): string {
            console.log("Recorder: stub start", mode);
            return "not implemented";
        }

        function stop(): void {
            console.log("Recorder: stub stop");
        }

        function togglePause(): void {
            console.log("Recorder: stub togglePause");
        }

        function isRunning(): bool {
            return root.running;
        }
    }
}
