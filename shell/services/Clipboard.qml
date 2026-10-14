pragma Singleton

import "../utils/fuzzysort.js" as Fuzzy
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// cliphist front-end: `cliphist list` rows (id\tpreview), lazy image decoding into cache/clip/<id>.png,
// pins persisted in state/clip-pins.json, delete with the original line on stdin, copy via wl-copy.
Singleton {
    id: root

    readonly property string pinsPath: `${Paths.state}/clip-pins.json`
    readonly property string imageDir: `${Paths.cache}/clip`

    property list<var> raw: []
    property list<string> pins: []
    property bool pinsLoaded: false
    property var decoded: ({})     // id -> true once the png exists
    property int decodeRev: 0
    property bool busy: false

    // Pinned rows first (in pin order), then the rest in cliphist order (newest first).
    readonly property list<var> entries: {
        const _d = decodeRev;
        const pinned = [];
        const rest = [];
        for (const r of raw) {
            const e = Object.assign({}, r, {
                pinned: pins.includes(r.id),
                imagePath: r.isImage && decoded[r.id] ? `${imageDir}/${r.id}.png` : ""
            });
            (e.pinned ? pinned : rest).push(e);
        }
        pinned.sort((a, b) => pins.indexOf(a.id) - pins.indexOf(b.id));
        return pinned.concat(rest);
    }

    readonly property list<var> prepared: entries.map(e => ({ _item: e, preview: Fuzzy.prepare(e.preview) }))

    function search(query: string): list<var> {
        const q = (query ?? "").trim();
        const limit = Config.launcher.maxResults ?? 40;
        if (!q)
            return entries.slice(0, limit);
        return Fuzzy.go(q, prepared, { key: "preview", limit: limit, threshold: 0.15 }).map(r => r.obj._item);
    }

    function refresh(): void {
        listProc.running = true;
    }

    function parseList(text: string): void {
        const out = [];
        for (const line of text.split("\n")) {
            if (!line)
                continue;
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            const id = line.slice(0, tab);
            const preview = line.slice(tab + 1);
            const isImage = /^\[\[ binary data .* (png|jpg|jpeg|gif|bmp|webp) /i.test(preview);
            out.push({ id: id, preview: preview, isImage: isImage, line: line });
        }
        raw = out;
    }

    // Request a decode of an image entry; `imagePath` is filled once the png exists.
    function ensureImage(id: string): void {
        if (!id || decoded[id] || pendingDecode.includes(id))
            return;
        pendingDecode.push(id);
        pumpDecode();
    }

    property list<string> pendingDecode: []

    function pumpDecode(): void {
        if (decodeProc.running || pendingDecode.length === 0)
            return;
        const id = pendingDecode[0];
        decodeProc.currentId = id;
        decodeProc.command = ["sh", "-c", `mkdir -p "$0" && cliphist decode "$1" > "$0/$1.png"`, imageDir, id];
        decodeProc.running = true;
    }

    function copy(entry: var): void {
        if (!entry?.id)
            return;
        Quickshell.execDetached(["sh", "-c", `cliphist decode "$0" | wl-copy`, entry.id]);
    }

    function remove(entry: var): void {
        if (!entry?.line)
            return;
        if (entry.pinned)
            setPinned(entry, false);
        deleteProc.stdinEnabled = true;
        deleteProc.running = true;
        deleteProc.write(entry.line + "\n");
        deleteProc.stdinEnabled = false;   // closes stdin so cliphist reads EOF
    }

    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        raw = [];
    }

    function setPinned(entry: var, pinned: bool): void {
        if (!entry?.id)
            return;
        const next = pins.filter(p => p !== entry.id);
        if (pinned)
            next.unshift(entry.id);
        pins = next;
        if (pinsLoaded)
            saveTimer.restart();
    }

    function togglePin(entry: var): void {
        setPinned(entry, !entry.pinned);
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        onRunningChanged: root.busy = running
        stdout: StdioCollector {
            onStreamFinished: root.parseList(text)
        }
    }

    Process {
        id: decodeProc
        property string currentId: ""
        onExited: (code, status) => {
            root.pendingDecode = root.pendingDecode.filter(p => p !== currentId);
            if (code === 0) {
                const next = Object.assign({}, root.decoded);
                next[currentId] = true;
                root.decoded = next;
                root.decodeRev++;
            }
            root.pumpDecode();
        }
    }

    Process {
        id: deleteProc
        command: ["cliphist", "delete"]
        stdinEnabled: true
        onExited: root.refresh()
    }

    Timer {
        id: saveTimer
        interval: 200
        onTriggered: pinsFile.setText(JSON.stringify(root.pins, null, 2))
    }

    FileView {
        id: pinsFile
        path: root.pinsPath
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.pins = Array.isArray(parsed) ? parsed.map(String) : [];
            } catch (e) {
                root.pins = [];
            }
            root.pinsLoaded = true;
        }
        onLoadFailed: err => {
            root.pinsLoaded = true;
            if (err !== FileViewError.FileNotFound)
                console.warn("Clipboard: cannot read", path, err);
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", imageDir, Paths.state])
}
