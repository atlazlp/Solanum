pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "Defaults.js" as Defaults

// Shell configuration. `~/.config/solanum/shell.json` deep-merged over Defaults.js,
// plus `monitors/<name>.json` overrides available through forScreen(name).
// The only writer is save(dottedKey, value) (used by Settings); writes are atomic.
Singleton {
    id: root

    // Raw user json (no defaults) and the merged result the UI reads.
    property var user: ({})
    property var data: Defaults.defaults()
    property var monitorOverrides: ({})

    // Section shortcuts; rebinding `data` re-evaluates every one of these.
    readonly property var appearance: data.appearance
    readonly property var screens: data.screens
    readonly property var modules: data.modules
    readonly property var bar: data.bar
    readonly property var general: data.general
    readonly property var launcher: data.launcher
    readonly property var notifs: data.notifs
    readonly property var osd: data.osd
    readonly property var session: data.session
    readonly property var utilities: data.utilities
    readonly property var quantumMoon: data.quantumMoon
    readonly property var audio: data.audio
    readonly property var brightness: data.brightness
    readonly property var nightlight: data.nightlight
    readonly property var gameMode: data.gameMode
    readonly property var shiplog: data.shiplog
    readonly property var updates: data.updates
    readonly property var qm: data.qm

    readonly property bool loaded: file.loaded
    signal reload()

    function get(dotted: string, fallback: var): var {
        return Defaults.getPath(data, dotted, fallback);
    }

    // Value from Defaults.js, ignoring shell.json. Settings uses this for reset.
    function baseline(dotted: string): var {
        return Defaults.getPath(Defaults.defaults(), dotted, undefined);
    }

    // Config as seen from one screen: data deep-merged with monitors/<name>.json.
    function forScreen(name: string): var {
        const over = monitorOverrides[name];
        return over ? Defaults.merge(data, over) : data;
    }

    function getFor(name: string, dotted: string, fallback: var): var {
        return Defaults.getPath(forScreen(name), dotted, fallback);
    }

    // Persist one key into shell.json (atomic write). The in-memory `data` updates immediately.
    function save(dotted: string, value: var): void {
        const next = Defaults.clone(user);
        Defaults.setPath(next, dotted, value);
        user = next;
        rebuild();
        file.setText(JSON.stringify(user, null, 4) + "\n");
    }

    function rebuild(): void {
        data = Defaults.merge(Defaults.defaults(), user);
        reload();
    }

    function applyText(text: string): void {
        try {
            const parsed = text.trim().length ? JSON.parse(text) : {};
            user = Defaults.isPlainObject(parsed) ? parsed : {};
        } catch (e) {
            console.warn("Config: invalid shell.json, keeping previous values:", e);
            return;
        }
        rebuild();
    }

    FileView {
        id: file

        path: Paths.shellConfig
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("Config: could not load", path, err);
            root.user = {};
            root.rebuild();
        }
    }

    Variants {
        model: Quickshell.screens

        FileView {
            required property ShellScreen modelData

            path: `${Paths.config}/monitors/${modelData.name}.json`
            watchChanges: true
            printErrors: false
            onLoaded: {
                try {
                    const parsed = JSON.parse(text());
                    const next = Object.assign({}, root.monitorOverrides);
                    next[modelData.name] = parsed;
                    root.monitorOverrides = next;
                    root.reload();
                } catch (e) {
                    console.warn("Config: invalid monitor override", path, e);
                }
            }
            onFileChanged: reload()
            onLoadFailed: err => {
                if (err !== FileViewError.FileNotFound)
                    console.warn("Config: could not load", path, err);
                if (root.monitorOverrides[modelData.name] !== undefined) {
                    const next = Object.assign({}, root.monitorOverrides);
                    delete next[modelData.name];
                    root.monitorOverrides = next;
                    root.reload();
                }
            }
        }
    }
}
