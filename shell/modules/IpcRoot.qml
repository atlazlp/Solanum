import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// `launcher` and `controlCenter` IPC targets (the launcher panel reads Launcher.requestedMode).
Scope {
    id: root

    // Mode requested by `launcher open <mode>`; the launcher panel consumes it when it loads.
    property string requestedMode: ""
    property bool interrupted: false

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.requestedMode = "";
            Visibilities.toggle("launcher", null);
        }

        function open(mode: string): void {
            root.requestedMode = mode ?? "";
            Visibilities.open("launcher", null);
        }

        function close(): void {
            Visibilities.close("launcher", null);
        }

        function interrupt(): void {
            root.interrupted = true;
        }

        function mode(): string {
            return root.requestedMode;
        }
    }

    IpcHandler {
        target: "controlCenter"

        function open(): void {
            Visibilities.open("settings", null);
        }
    }
}
