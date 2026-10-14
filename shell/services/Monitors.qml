pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Hotplug: `monitors hotplug <name> <bool>` promotes/demotes a screen as runtime main
// by writing state/screens-runtime.json ({ "main": name }); Screens picks it up via its FileView.
Singleton {
    id: root

    function setRuntimeMain(name: string): void {
        runtimeFile.setText(JSON.stringify({ main: name }, null, 2) + "\n");
    }

    function clearRuntimeMain(): void {
        runtimeFile.setText("{}\n");
    }

    FileView {
        id: runtimeFile
        path: Paths.screensRuntime
        atomicWrites: true
        printErrors: false
        blockLoading: false
        onLoadFailed: err => {}
        onSaveFailed: err => console.warn("Monitors: could not write", path, err)
    }

    IpcHandler {
        target: "monitors"

        function hotplug(name: string, connected: bool): string {
            if (connected) {
                if (name === Config.screens.roles?.main) {
                    root.clearRuntimeMain();
                    return `main restored: ${name}`;
                }
                if (Screens.names.includes(Config.screens.roles?.main))
                    return `ignored: configured main present`;
                root.setRuntimeMain(name);
                return `runtime main: ${name}`;
            }
            if (name === Config.screens.roles?.main || name === Screens.runtimeMain) {
                const fallback = Config.screens.fallbackMain || Screens.names.find(n => n !== name) || "";
                if (fallback) {
                    root.setRuntimeMain(fallback);
                    return `runtime main: ${fallback}`;
                }
            }
            return "no change";
        }

        function main(): string {
            return Screens.mainName;
        }
    }
}
