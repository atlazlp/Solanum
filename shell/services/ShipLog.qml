pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Persistent notification history ("ship log"): every notification becomes an entry in
// ~/.local/state/quantum-moon/ship-log.json. Entries received while DND is on are "rumors"
// (hidden until the user looks at them). Groups are per app, edges link the chronological
// chain inside a group and cross-app entries that arrive close together sharing a word.
Singleton {
    id: root

    property list<var> entries: []      // newest first
    property bool loaded: false
    property int seq: 0
    property string pendingQuery: ""    // set by `shiplog search <q>` before the panel opens
    property string pendingSelect: ""   // app group to select once the panel is up (`shiplog select`)
    property string pendingReveal: ""   // entry id to open once the panel is up (`shiplog reveal`)

    signal searchRequested(string q)
    signal selectRequested(string app)
    signal revealRequested(string id)
    property int generation: 0          // bumps on every mutation (bindings on nested fields)

    readonly property int maxEntries: Config.shiplog.maxEntries ?? 500
    readonly property int retentionDays: Config.shiplog.retentionDays ?? 30
    readonly property int linkWindowMs: 2 * 60 * 1000
    readonly property int minTokenLength: 5

    readonly property int unreadCount: entries.filter(e => !e.read).length
    readonly property int rumorCount: entries.filter(e => e.rumor).length

    // [{ app, desktopEntry, icon, entries: [newest first], latest, count, unread, rumors }]
    readonly property list<var> groups: {
        void generation;
        const map = new Map();
        for (const e of entries) {
            const key = e.app || "Unknown";
            if (!map.has(key))
                map.set(key, { app: key, desktopEntry: e.desktopEntry ?? "", icon: e.icon ?? "", entries: [], latest: 0, count: 0, unread: 0, rumors: 0 });
            const g = map.get(key);
            g.entries.push(e);
            g.count++;
            g.latest = Math.max(g.latest, e.ts);
            if (!e.read)
                g.unread++;
            if (e.rumor)
                g.rumors++;
            if (!g.desktopEntry && e.desktopEntry)
                g.desktopEntry = e.desktopEntry;
        }
        return [...map.values()].sort((a, b) => b.latest - a.latest);
    }

    // [{ from, to, kind: "chain" | "link", rumor, fromApp, toApp }]
    readonly property list<var> edges: {
        void generation;
        const out = [];
        const byApp = new Map();
        const asc = entries.slice().sort((a, b) => a.ts - b.ts);
        for (const e of asc) {
            const key = e.app || "Unknown";
            const prev = byApp.get(key);
            if (prev)
                out.push({ from: prev.id, to: e.id, kind: "chain", rumor: !!(prev.rumor || e.rumor), fromApp: key, toApp: key });
            byApp.set(key, e);
        }
        const tokensOf = e => {
            const set = new Set();
            for (const t of `${e.summary} ${e.body}`.toLowerCase().split(/[^a-z0-9\u00c0-\u024f\u0400-\u04ff]+/))
                if (t.length >= minTokenLength)
                    set.add(t);
            return set;
        };
        const toks = asc.map(tokensOf);
        for (let i = 0; i < asc.length; i++) {
            for (let j = i + 1; j < asc.length && asc[j].ts - asc[i].ts <= linkWindowMs; j++) {
                if ((asc[i].app || "Unknown") === (asc[j].app || "Unknown"))
                    continue;
                let shared = false;
                for (const t of toks[i])
                    if (toks[j].has(t)) {
                        shared = true;
                        break;
                    }
                if (shared)
                    out.push({ from: asc[i].id, to: asc[j].id, kind: "link", rumor: !!(asc[i].rumor || asc[j].rumor), fromApp: asc[i].app || "Unknown", toApp: asc[j].app || "Unknown" });
            }
        }
        return out;
    }

    function record(n: NotifData, rumor: bool): void {
        const entry = {
            id: `${Date.now()}-${++seq}`,
            notifId: n.id,
            ts: n.time.getTime(),
            app: n.appName || "Unknown",
            desktopEntry: n.desktopEntry ?? "",
            icon: n.appIcon ?? "",
            image: (n.image ?? "").startsWith("image://") ? "" : (n.image ?? ""),
            summary: n.summary ?? "",
            body: n.body ?? "",
            urgency: n.urgency,
            actions: (n.actions ?? []).map(a => ({ id: a.identifier, text: a.text })),
            rumor: !!rumor,
            read: false,
            pinned: false
        };
        entries = prune([entry, ...entries]);
        touch();
        // Cached images land a moment later; pick the path up once it exists.
        if ((n.image ?? "").startsWith("image://"))
            n.imageChanged.connect(() => {
                if (!n.image.startsWith("image://"))
                    update(entry.id, { image: n.image });
            });
    }

    function prune(list: var): var {
        const cutoff = Date.now() - retentionDays * 86400000;
        let out = list.filter(e => e.pinned || e.ts >= cutoff);
        if (out.length > maxEntries) {
            const pinned = out.filter(e => e.pinned);
            const rest = out.filter(e => !e.pinned).slice(0, Math.max(0, maxEntries - pinned.length));
            out = [...pinned, ...rest].sort((a, b) => b.ts - a.ts);
        }
        return out;
    }

    function byId(id: string): var {
        return entries.find(e => e.id === id) ?? null;
    }

    function update(id: string, patch: var): void {
        const i = entries.findIndex(e => e.id === id);
        if (i < 0)
            return;
        const next = entries.slice();
        next[i] = Object.assign({}, next[i], patch);
        entries = next;
        touch();
    }

    function markRead(id: string): void {
        const e = byId(id);
        if (e && (!e.read || e.rumor))
            update(id, { read: true, rumor: false });
    }

    function markAllRead(): void {
        if (!entries.some(e => !e.read || e.rumor))
            return;
        entries = entries.map(e => Object.assign({}, e, { read: true, rumor: false }));
        touch();
    }

    function togglePin(id: string): void {
        const e = byId(id);
        if (e)
            update(id, { pinned: !e.pinned });
    }

    function remove(id: string): void {
        if (!byId(id))
            return;
        entries = entries.filter(e => e.id !== id);
        touch();
    }

    function removeGroup(app: string): void {
        entries = entries.filter(e => (e.app || "Unknown") !== app);
        touch();
    }

    function clear(): void {
        entries = entries.filter(e => e.pinned);
        touch();
    }

    function matches(e: var, q: string): bool {
        if (!q)
            return true;
        const needle = q.toLowerCase();
        return `${e.app} ${e.summary} ${e.body}`.toLowerCase().includes(needle);
    }

    // Re-invoke the action on the still-open notification, else launch the app.
    function act(entry: var, actionId: string): void {
        const live = Notifs.byId(entry.notifId);
        if (live && actionId && live.invokeAction(actionId)) {
            live.close();
            return;
        }
        if (live && !actionId) {
            Notifs.activate(live);
            return;
        }
        Notifs.launchApp(entry.app, entry.desktopEntry);
    }

    function isOpen(entry: var): bool {
        return Notifs.byId(entry.notifId) !== null;
    }

    function open(query: string): void {
        pendingQuery = query ?? "";
        Visibilities.open("shipLog", null);
        searchRequested(pendingQuery);
    }

    // Open the panel on a group / an entry. If the panel is already up the signal is enough;
    // otherwise the panel consumes the pending value in reveal().
    function select(app: string): void {
        pendingSelect = app ?? "";
        Visibilities.open("shipLog", null);
        selectRequested(pendingSelect);
    }

    function reveal(id: string): void {
        pendingReveal = id ?? "";
        Visibilities.open("shipLog", null);
        revealRequested(pendingReveal);
    }

    function touch(): void {
        generation++;
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: storage.setText(JSON.stringify({ version: 1, entries: root.entries }, null, 1))
    }

    Timer {
        // Periodic retention sweep.
        interval: 3600000
        running: root.loaded
        repeat: true
        onTriggered: {
            const next = root.prune(root.entries);
            if (next.length !== root.entries.length) {
                root.entries = next;
                root.touch();
            }
        }
    }

    FileView {
        id: storage

        path: `${Paths.state}/ship-log.json`
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                const list = Array.isArray(data) ? data : (data.entries ?? []);
                root.entries = root.prune(list.filter(e => e && e.id).sort((a, b) => b.ts - a.ts));
                root.seq = root.entries.length;
                root.generation++;
            } catch (e) {
                console.warn("ShipLog: cannot parse", path, e);
            }
            root.loaded = true;
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => setText(JSON.stringify({ version: 1, entries: [] })));
        }
    }

    IpcHandler {
        target: "shiplog"

        function open(): void {
            root.open("");
        }

        function search(q: string): void {
            root.open(q);
        }

        function markAllRead(): void {
            root.markAllRead();
        }

        function select(app: string): void {
            root.select(app);
        }

        function reveal(id: string): void {
            root.reveal(id);
        }

        function unread(): int {
            return root.unreadCount;
        }

        function count(): int {
            return root.entries.length;
        }

        function clear(): void {
            root.clear();
        }

        function edges(): string {
            return JSON.stringify(root.edges.map(e => `${e.kind}:${e.fromApp}->${e.toApp}${e.rumor ? "?" : ""}`));
        }
    }
}
