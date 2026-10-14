pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Session lock state + IPC. The WlSessionLock itself lives in modules/lock/Lock.qml (loaded by
// shell.qml when DevFlags.sessionLock); it mirrors `locked` and reports back through `hostActive`.
// lock(): closes the session drawer, sets locked, arms the locked-sleep timer script.
// unlock(): asks the host to fade (<= 200 ms) then clears `locked`; without a host it clears directly.
Singleton {
    id: root

    property bool locked: false
    // True while modules/lock/Lock.qml is loaded (it owns the WlSessionLock and the unlock fade).
    property bool hostActive: false
    // Debug: show the lock surface content in a normal PanelWindow (`lock preview [seconds]`).
    property bool previewActive: false
    property int previewSeconds: 8

    signal lockRequested()
    signal unlockRequested()

    readonly property int lockedSleepAfter: Config.general.idle?.lockedSleepAfter ?? 300
    readonly property list<string> lockedSleepScripts: [`${Quickshell.env("HOME")}/.config/hypr/scripts/locked-sleep-after.sh`, `${Quickshell.env("HOME")}/.config/caelestia/scripts/locked-sleep-after.sh`]
    property string lockedSleepScript: ""

    function lock(): void {
        Visibilities.close("session", null);
        if (root.locked)
            return;
        root.locked = true;
        root.lockRequested();
        root.armLockedSleep();
    }

    function unlock(): void {
        if (!root.locked)
            return;
        root.unlockRequested();
        if (!root.hostActive)
            root.locked = false;
    }

    // Called by the host once its fade is done (or straight away when there is no UI to fade).
    function finishUnlock(): void {
        root.locked = false;
    }

    function preview(): void {
        root.previewActive = false;
        root.previewActive = true;
    }

    function armLockedSleep(): void {
        if (!root.lockedSleepScript || !root.hostActive)
            return;
        Quickshell.execDetached(["bash", root.lockedSleepScript, "arm", String(root.lockedSleepAfter)]);
    }

    function disarmLockedSleep(): void {
        if (!root.lockedSleepScript)
            return;
        Quickshell.execDetached(["bash", root.lockedSleepScript, "disarm"]);
    }

    onLockedChanged: {
        if (!locked) {
            root.disarmLockedSleep();
            Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "on"]);
        }
    }

    // Pick the first locked-sleep script that exists (hypr first, caelestia as legacy).
    Process {
        id: scriptProbe

        running: true
        command: ["sh", "-c", `for f in ${root.lockedSleepScripts.map(p => `"${p}"`).join(" ")}; do [ -f "$f" ] && { echo "$f"; exit 0; }; done; exit 1`]
        stdout: StdioCollector {
            onStreamFinished: root.lockedSleepScript = text.trim()
        }
    }

    // Preview host (debug): loaded by URL so this singleton does not import the module.
    Loader {
        active: root.previewActive
        source: Qt.resolvedUrl("../modules/lock/LockPreview.qml")
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

        function preview(seconds: int): void {
            root.previewSeconds = seconds > 0 ? seconds : 8;
            root.preview();
        }
    }
}
