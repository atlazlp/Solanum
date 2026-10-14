import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/Defaults.js" as Defaults

// A small JSON file (vpn.json, services.json) with the same get/has/set surface as SettingsStore.
// Writes are atomic and debounced; a missing file is created on the first edit.
Scope {
    id: root

    required property string path
    property var data: ({})
    property var pending: ({})
    property int generation: 0
    readonly property bool loaded: file.loaded
    readonly property int debounceMs: 300

    function get(key: string, fallback: var): var {
        if (key in pending)
            return pending[key];
        return Defaults.getPath(data, key, fallback);
    }

    function has(key: string): bool {
        return true;
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
        const next = Defaults.clone(data);
        for (const k of keys)
            Defaults.setPath(next, k, pending[k]);
        pending = {};
        data = next;
        generation++;
        file.setText(JSON.stringify(data, null, 2) + "\n");
    }

    function applyText(text: string): void {
        try {
            const parsed = text.trim().length ? JSON.parse(text) : {};
            data = Defaults.isPlainObject(parsed) ? parsed : {};
        } catch (e) {
            console.warn("JsonStore: invalid", path, e);
            return;
        }
        generation++;
    }

    Timer {
        id: flush
        interval: root.debounceMs
        onTriggered: root.flushNow()
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("JsonStore: could not load", path, err);
            root.data = {};
            root.generation++;
        }
    }
}
