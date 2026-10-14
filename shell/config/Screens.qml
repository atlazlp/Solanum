pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screen roles (main/left/right) and the module -> roles matrix.
// `state/screens-runtime.json` ({ "main": "<name>" }) promotes another output to main at runtime (hotplug).
Singleton {
    id: root

    property string runtimeMain: ""

    readonly property var roles: Config.screens.roles ?? ({})
    readonly property list<string> names: Quickshell.screens.map(s => s.name)

    // The screen currently acting as "main": runtime override > configured main > fallbackMain > first screen.
    readonly property string mainName: {
        const present = n => n && names.includes(n);
        if (present(runtimeMain))
            return runtimeMain;
        if (present(roles.main))
            return roles.main;
        if (present(Config.screens.fallbackMain))
            return Config.screens.fallbackMain;
        return names[0] ?? "";
    }
    readonly property ShellScreen mainScreen: Quickshell.screens.find(s => s.name === mainName) ?? null

    function roleOf(name: string): string {
        if (name === mainName)
            return "main";
        for (const role in roles) {
            if (role !== "main" && roles[role] === name)
                return role;
        }
        return "";
    }

    function nameOf(role: string): string {
        if (role === "main")
            return mainName;
        return roles[role] ?? "";
    }

    // Is `module` (a key of Config.modules, e.g. "bar", "hover.launcher") enabled on screen `name`?
    function isEnabled(module: string, name: string): bool {
        const entry = Config.modules[module];
        if (entry === undefined || entry === null)
            return false;
        if (entry === "*" || entry === true)
            return true;
        if (entry === false)
            return false;
        if (Array.isArray(entry)) {
            if (entry.includes("*") || entry.includes(name))
                return true;
            const role = roleOf(name);
            return role !== "" && entry.includes(role);
        }
        return false;
    }

    function screenByName(name: string): ShellScreen {
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }

    FileView {
        path: Paths.screensRuntime
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.runtimeMain = String(parsed?.main ?? "");
            } catch (e) {
                console.warn("Screens: invalid screens-runtime.json:", e);
                root.runtimeMain = "";
            }
        }
        onFileChanged: reload()
        onLoadFailed: err => {
            root.runtimeMain = "";
        }
    }
}
