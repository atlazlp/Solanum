pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Per-screen drawer visibility registry + the `drawers` IPC target.
Singleton {
    id: root

    property var screens: new Map()
    property var popouts: new Map()
    property int generation: 0   // bumps whenever a DrawerVisibilities is registered so bindings refresh

    // Exclusive drawers close each other when opened (one big panel at a time).
    readonly property list<string> exclusive: ["launcher", "windowPicker", "dashboard", "sidebar", "shipLog", "session", "quantumMoon", "services", "kvm", "audio", "updates", "settings"]
    readonly property list<string> fullscreenBlocked: ["session", "dashboard", "sidebar", "quantumMoon"]

    function load(screen: ShellScreen, vis: DrawerVisibilities): void {
        screens.set(screen.name, vis);
        generation++;
    }

    function unload(screen: ShellScreen): void {
        screens.delete(screen.name);
        generation++;
    }

    function forScreen(name: string): DrawerVisibilities {
        return screens.get(name) ?? null;
    }

    function getForActive(): DrawerVisibilities {
        const mon = Hypr.focusedMonitor;
        const key = mon && mon.name ? mon.name : Screens.mainName;
        return screens.get(key) ?? screens.get(Screens.mainName) ?? null;
    }

    function registerPopout(name: string, host: var): void {
        popouts.set(name, host);
        generation++;
    }

    function popoutFor(name: string): var {
        return popouts.get(name) ?? null;
    }

    function isDrawer(name: string): bool {
        return (screens.values().next().value?.names ?? []).includes(name);
    }

    // Open `name` on `vis` (or the focused screen), closing other exclusive drawers.
    function open(name: string, vis: DrawerVisibilities): void {
        const v = vis ?? getForActive();
        if (!v)
            return;
        if (!v.names.includes(name)) {
            console.warn(`Visibilities: unknown drawer "${name}"`);
            return;
        }
        if (exclusive.includes(name)) {
            for (const other of exclusive)
                if (other !== name)
                    v[other] = false;
        }
        v[name] = true;
    }

    function close(name: string, vis: DrawerVisibilities): void {
        const v = vis ?? getForActive();
        if (v && v.names.includes(name))
            v[name] = false;
    }

    function toggle(name: string, vis: DrawerVisibilities): void {
        const v = vis ?? getForActive();
        if (!v)
            return;
        if (v[name])
            close(name, v);
        else
            open(name, v);
    }

    function closeAll(): void {
        for (const [, v] of screens)
            v.closeAll();
    }

    function anyOpen(): bool {
        for (const [, v] of screens)
            if (v.anyOpen())
                return true;
        return false;
    }

    IpcHandler {
        target: "drawers"

        function toggle(drawer: string): void {
            if (!root.isDrawer(drawer)) {
                console.warn(`drawers: "${drawer}" does not exist`);
                return;
            }
            const v = root.getForActive();
            if (v && !v[drawer] && Hypr.focusedHasFullscreen && root.fullscreenBlocked.includes(drawer) && !Config.general.showOverFullscreen)
                return;
            root.toggle(drawer, v);
        }

        function open(drawer: string): void {
            root.open(drawer, null);
        }

        function close(drawer: string): void {
            root.close(drawer, null);
        }

        function closeAll(): void {
            root.closeAll();
        }

        function list(): string {
            const v = root.getForActive();
            if (!v)
                return "";
            return v.names.map(n => `${n}${v[n] ? " *" : ""}`).join("\n");
        }
    }
}
