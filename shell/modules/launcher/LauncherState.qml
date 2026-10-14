pragma Singleton

import QtQuick
import Quickshell

// Shared launcher state: the mode requested over IPC (`launcher open <mode>`), consumed by
// Launcher.qml when it loads or when the request changes while it is open.
Singleton {
    id: root

    readonly property list<string> modes: ["apps", "windows", "clip", "emoji", "calc"]

    property string requestedMode: ""
    property bool interrupted: false

    signal modeRequested(string mode)

    function request(mode: string): void {
        const m = (mode ?? "").trim();
        requestedMode = modes.includes(m) ? m : "";
        modeRequested(requestedMode);
    }

    function consume(): string {
        const m = requestedMode;
        requestedMode = "";
        return m;
    }
}
