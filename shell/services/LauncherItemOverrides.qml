pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Per-item label/subtitle/icon overrides for launcher apps and window-picker rows.
// Store: state/launcher-item-overrides.json  { apps: { id: {label, subtitle, iconFile} }, windows: { class: {...} } }
// Icons: data/launcher-icons/<safeKey>.<ext> (copied from the path the user typed in ItemEditor).
Singleton {
    id: root

    readonly property string iconsDir: `${Paths.data}/launcher-icons`
    readonly property string storePath: `${Paths.state}/launcher-item-overrides.json`

    property var data: ({ apps: {}, windows: {} })
    property bool loaded: false
    property int revision: 0

    // Editor request consumed by Launcher / WindowPicker (they own the Modal).
    property var editTarget: null
    readonly property bool editOpen: editTarget !== null && editTarget !== undefined

    function openEditor(target: var): void {
        editTarget = target;
    }

    function closeEditor(): void {
        editTarget = null;
    }

    function safeKey(key: string): string {
        return (key ?? "").toString().trim().replace(/[^a-zA-Z0-9._-]+/g, "_") || "item";
    }

    function bucket(type: string): string {
        return type === "window" ? "windows" : "apps";
    }

    function entry(type: string, key: string): var {
        const b = root.data[bucket(type)];
        if (!b || !key)
            return null;
        return b[key] ?? null;
    }

    function hasOverride(type: string, key: string): bool {
        const _r = revision;
        return entry(type, key) !== null;
    }

    function displayLabel(type: string, key: string, fallback: string): string {
        const _r = revision;
        const label = (entry(type, key)?.label ?? "").toString().trim();
        return label || fallback;
    }

    function subtitle(type: string, key: string, fallback: string): string {
        const _r = revision;
        const sub = (entry(type, key)?.subtitle ?? "").toString().trim();
        return sub || fallback;
    }

    // Returns a file:// url for an overridden icon or `fallback` (icon name/path) otherwise.
    function iconSource(type: string, key: string, fallback: string): string {
        const _r = revision;
        const file = (entry(type, key)?.iconFile ?? "").toString().trim();
        if (file)
            return `file://${iconsDir}/${file}?r=${revision}`;
        return fallback;
    }

    function extensionFor(path: string): string {
        const m = path.toLowerCase().match(/\.([a-z0-9]+)$/);
        if (!m)
            return "png";
        return m[1] === "jpeg" ? "jpg" : m[1];
    }

    function deleteIconFile(fileName: string): void {
        const name = (fileName ?? "").toString().trim();
        if (!name)
            return;
        Quickshell.execDetached(["rm", "-f", `${iconsDir}/${name}`]);
    }

    function saveOverride(type: string, key: string, labelVal: string, subtitleVal: string, iconSourcePath: string): bool {
        if (!key)
            return false;
        const b = bucket(type);
        const next = JSON.parse(JSON.stringify(root.data));
        if (!next[b])
            next[b] = {};
        const prev = next[b][key] ?? {};
        const record = {
            label: (labelVal ?? "").toString().trim(),
            subtitle: (subtitleVal ?? "").toString().trim(),
            iconFile: prev.iconFile ?? ""
        };

        const src = Paths.expand((iconSourcePath ?? "").toString().trim().replace(/^file:\/\//, ""));
        if (src) {
            const destName = `${safeKey(key)}.${extensionFor(src)}`;
            if (prev.iconFile && prev.iconFile !== destName)
                deleteIconFile(prev.iconFile);
            record.iconFile = destName;
            copyProc.command = ["sh", "-c", `mkdir -p "$0" && cp -f "$1" "$0/$2"`, iconsDir, src, destName];
            copyProc.running = true;
        }

        if (!record.label && !record.subtitle && !record.iconFile)
            delete next[b][key];
        else
            next[b][key] = record;

        root.data = next;
        root.revision++;
        persist();
        return true;
    }

    function resetOverride(type: string, key: string): void {
        if (!key)
            return;
        const b = bucket(type);
        const next = JSON.parse(JSON.stringify(root.data));
        if (!next[b] || !next[b][key])
            return;
        deleteIconFile(next[b][key]?.iconFile);
        delete next[b][key];
        root.data = next;
        root.revision++;
        persist();
    }

    function persist(): void {
        if (loaded)
            saveTimer.restart();
    }

    Process {
        id: copyProc
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("LauncherItemOverrides: icon copy failed", code);
            root.revision++;
        }
    }

    Timer {
        id: saveTimer
        interval: 200
        onTriggered: storage.setText(JSON.stringify(root.data, null, 2))
    }

    FileView {
        id: storage
        printErrors: false
        path: root.storePath
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.data = { apps: parsed?.apps ?? {}, windows: parsed?.windows ?? {} };
            } catch (e) {
                root.data = { apps: {}, windows: {} };
            }
            root.loaded = true;
            root.revision++;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                // First run: seed from the legacy caelestia store if it exists (read-only copy).
                seedProc.running = true;
            } else {
                console.warn("LauncherItemOverrides: cannot read", path, err);
                root.loaded = true;
            }
        }
    }

    Process {
        id: seedProc
        command: ["sh", "-c", `
            mkdir -p "$1" "$2" "$5"
            if [ -f "$3" ]; then cp -n "$3" "$1/launcher-item-overrides.json"; else printf '{"apps":{},"windows":{}}\n' > "$1/launcher-item-overrides.json"; fi
            if [ -d "$4" ]; then cp -n "$4"/* "$2"/ 2>/dev/null; fi
            exit 0`, "qm", Paths.state, iconsDir,
            `${Paths.home}/.local/state/caelestia/launcher-item-overrides.json`,
            `${Paths.home}/.local/share/caelestia/launcher-icons`, Paths.data]
        onExited: storage.reload()
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", iconsDir])
}
