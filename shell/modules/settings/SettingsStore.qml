pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Debounced writer over Config.save(). Rows read through get() (pending edits win over the
// merged config) and write through set(); pending keys flush to shell.json 300 ms after the last edit.
Singleton {
    id: root

    property var pending: ({})
    property int generation: 0
    readonly property int debounceMs: 300

    function get(key: string, fallback: var): var {
        if (key in pending)
            return pending[key];
        return Config.get(key, fallback);
    }

    // Only keys that exist in Defaults.js (or the user's file) get a row.
    function has(key: string): bool {
        return Config.get(key, undefined) !== undefined;
    }

    function set(key: string, value: var): void {
        const next = Object.assign({}, pending);
        next[key] = value;
        pending = next;
        generation++;
        flush.restart();
    }

    function flushNow(): void {
        const keys = Object.keys(pending);
        if (keys.length === 0)
            return;
        const batch = pending;
        pending = {};
        for (const k of keys)
            Config.save(k, batch[k]);
        generation++;
    }

    // "showAudio" -> "Show audio", "perMonitorWorkspaces" -> "Per monitor workspaces"
    function humanize(key: string): string {
        const s = key.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[._]/g, " ").toLowerCase();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    Timer {
        id: flush
        interval: root.debounceMs
        onTriggered: root.flushNow()
    }

    Connections {
        target: Config
        function onReload(): void {
            root.generation++;
        }
    }
}
