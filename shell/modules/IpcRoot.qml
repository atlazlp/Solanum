import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.launcher

// `launcher` and `controlCenter` IPC targets (the launcher panel reads LauncherState.requestedMode).
Scope {
    id: root

    // Mode requested by `launcher open <mode>`; the launcher panel consumes it when it loads.
    property string requestedMode: ""
    property bool interrupted: false

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.requestedMode = "";
            LauncherState.request("");
            Visibilities.toggle("launcher", null);
        }

        function open(mode: string): void {
            root.requestedMode = mode ?? "";
            LauncherState.request(mode ?? "");
            Visibilities.open("launcher", null);
        }

        function close(): void {
            Visibilities.close("launcher", null);
        }

        function interrupt(): void {
            root.interrupted = true;
            LauncherState.interrupted = true;
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
