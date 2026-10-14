pragma Singleton

import "../utils/fuzzysort.js" as Fuzzy
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Emoji picker data: assets/emoji.json ([{e,n,k,g}]) + recent list in state/emoji-recent.json.
Singleton {
    id: root

    readonly property string recentPath: `${Paths.state}/emoji-recent.json`
    readonly property int maxRecent: 24

    property list<var> all: []
    property list<string> recent: []
    property bool recentLoaded: false

    readonly property list<var> recentEntries: recent.map(e => all.find(a => a.e === e) ?? { e: e, n: "", k: "", g: "recent" })

    readonly property list<var> prepared: all.map(a => ({ _item: a, name: Fuzzy.prepare(a.n), keywords: Fuzzy.prepare(a.k) }))

    function search(query: string, limit: int): list<var> {
        const q = (query ?? "").trim();
        const lim = limit > 0 ? limit : 200;
        if (!q)
            return all.slice(0, lim);
        return Fuzzy.go(q, prepared, {
            keys: ["name", "keywords"],
            limit: lim,
            threshold: 0.2,
            scoreFn: r => Math.max(r[0]?.score ?? 0, (r[1]?.score ?? 0) * 0.8)
        }).map(r => r.obj._item);
    }

    function use(entry: var): void {
        const e = typeof entry === "string" ? entry : entry?.e;
        if (!e)
            return;
        Quickshell.execDetached(["wl-copy", e]);
        const next = [e, ...recent.filter(r => r !== e)].slice(0, maxRecent);
        recent = next;
        if (recentLoaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 200
        onTriggered: recentFile.setText(JSON.stringify(root.recent))
    }

    FileView {
        path: `${Paths.assets}/emoji.json`
        printErrors: true
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.all = Array.isArray(parsed) ? parsed : [];
            } catch (e) {
                console.warn("Emoji: bad emoji.json", e);
            }
        }
    }

    FileView {
        id: recentFile
        path: root.recentPath
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.recent = Array.isArray(parsed) ? parsed.map(String) : [];
            } catch (e) {
                root.recent = [];
            }
            root.recentLoaded = true;
        }
        onLoadFailed: err => {
            root.recentLoaded = true;
            if (err !== FileViewError.FileNotFound)
                console.warn("Emoji: cannot read", path, err);
        }
    }
}
