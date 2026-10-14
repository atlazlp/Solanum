pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

// Hyprland facade: monitors/workspaces/toplevels, keyboard state via `hyprctl devices -j`,
// dispatch() and emit(topic, payload) -> `hyprctl dispatch event qm:<topic>:<payload>`.
Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: {
        const t = Hyprland.activeToplevel;
        if (!t || (t.workspace?.name ?? "").startsWith("special:"))
            return null;
        return t;
    }
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1
    readonly property bool focusedHasFullscreen: focusedWorkspace?.hasFullscreen ?? false

    // Keyboard (from `hyprctl devices -j`, refreshed on activelayout events and `hypr refreshDevices`)
    property var keyboard: null
    readonly property bool capsLock: keyboard?.capsLock ?? false
    readonly property bool numLock: keyboard?.numLock ?? false
    readonly property string kbLayoutFull: keyboard?.active_keymap ?? "Unknown"
    readonly property string kbLayout: {
        const l = String(keyboard?.layout ?? "");
        const idx = keyboard?.active_layout_index ?? 0;
        const parts = l.split(",");
        return (parts[idx] ?? parts[0] ?? "??").trim() || "??";
    }
    property bool hadKeyboard: false

    signal configReloaded()
    signal event(string name, string data)

    function dispatch(request: string): void {
        Hyprland.dispatch(request);
    }

    // Custom event other tooling (Lua config, scripts) can listen to: qm:<topic>:<payload>
    function emit(topic: string, payload: string): void {
        Quickshell.execDetached(["hyprctl", "dispatch", "event", `qm:${topic}:${payload ?? ""}`]);
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function monitorByName(name: string): HyprlandMonitor {
        return monitors.values.find(m => m.name === name) ?? null;
    }

    function hasFullscreenOn(screen: ShellScreen): bool {
        const mon = monitorFor(screen);
        return mon?.activeWorkspace?.hasFullscreen ?? false;
    }

    function monitorNames(): list<string> {
        return monitors.values.map(m => m.name);
    }

    function refreshDevices(): void {
        devicesProc.running = true;
    }

    function refreshAll(): void {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: refreshDevices()

    onCapsLockChanged: {
        if (!Config.utilities.toasts.capsLockChanged)
            return;
        Toaster.toast(capsLock ? "Caps lock enabled" : "Caps lock disabled", "", capsLock ? "keyboard_capslock_badge" : "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!Config.utilities.toasts.numLockChanged)
            return;
        Toaster.toast(numLock ? "Num lock enabled" : "Num lock disabled", "", numLock ? "looks_one" : "timer_1");
    }

    onKbLayoutFullChanged: {
        if (hadKeyboard && Config.utilities.toasts.kbLayoutChanged)
            Toaster.toast("Keyboard layout changed", `Layout changed to: ${kbLayoutFull}`, "keyboard");
        hadKeyboard = !!keyboard;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            root.event(n, event.data);
            if (n.endsWith("v2"))
                return;
            if (n === "configreloaded") {
                root.configReloaded();
                root.refreshDevices();
            } else if (n === "activelayout") {
                root.refreshDevices();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
                if (n === "fullscreen")
                    Hyprland.refreshWorkspaces();
            }
        }
    }

    Process {
        id: devicesProc

        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const kbs = d.keyboards ?? [];
                    root.keyboard = kbs.find(k => k.main) ?? kbs[0] ?? null;
                } catch (e) {
                    console.warn("Hypr: cannot parse hyprctl devices:", e);
                }
            }
        }
    }

    IpcHandler {
        target: "hypr"

        function refreshDevices(): void {
            root.refreshDevices();
        }
    }
}
