pragma Singleton

import "../utils/fuzzysort.js" as Fuzzy
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Desktop application index: DesktopEntries filtered by noDisplay + Config.launcher.hidden,
// fuzzy search over name/comment/keywords/genericName with a launch-frequency boost
// (persisted in state/launch-frequency.json), favourites first when the query is empty.
Singleton {
    id: root

    readonly property string freqPath: `${Paths.state}/launch-frequency.json`

    property var frequency: ({})
    property bool freqLoaded: false
    property int revision: 0

    readonly property list<var> hiddenPatterns: (Config.launcher.hidden ?? []).map(p => {
        try {
            return new RegExp(p);
        } catch (e) {
            return null;
        }
    }).filter(r => r !== null)

    readonly property list<string> favourites: Config.launcher.favourites ?? []

    // Plain objects wrapping each DesktopEntry (the entry itself stays reachable as `entry`).
    readonly property list<var> apps: {
        const _r = revision;
        const vals = DesktopEntries.applications.values;
        const out = [];
        for (const e of vals) {
            if (!e || e.noDisplay)
                continue;
            const id = e.id ?? "";
            if (hiddenPatterns.some(rx => rx.test(id) || rx.test(e.name ?? "")))
                continue;
            out.push({
                id: id,
                entry: e,
                name: e.name ?? "",
                comment: e.comment ?? "",
                genericName: e.genericName ?? "",
                keywords: (e.keywords ?? []).join(" "),
                categories: (e.categories ?? []).join(" "),
                icon: e.icon ?? "",
                runInTerminal: e.runInTerminal ?? false,
                command: e.command ?? [],
                workingDirectory: e.workingDirectory ?? "",
                freq: frequency[id] ?? 0,
                favourite: favourites.includes(id)
            });
        }
        return out;
    }

    readonly property list<var> prepared: apps.map(a => ({
        _item: a,
        name: Fuzzy.prepare(a.name),
        comment: Fuzzy.prepare(a.comment),
        keywords: Fuzzy.prepare(a.keywords),
        genericName: Fuzzy.prepare(a.genericName)
    }))

    readonly property list<string> keys: ["name", "comment", "keywords", "genericName"]
    readonly property list<real> weights: [1, 0.3, 0.35, 0.4]

    function boost(freq: int): real {
        return Math.min(freq, 40) * 0.004;
    }

    function search(query: string): list<var> {
        const q = (query ?? "").trim();
        const limit = Config.launcher.maxResults ?? 40;
        if (!q) {
            const sorted = [...apps].sort((a, b) => {
                if (a.favourite !== b.favourite)
                    return a.favourite ? -1 : 1;
                if (a.favourite && b.favourite)
                    return favourites.indexOf(a.id) - favourites.indexOf(b.id);
                if (a.freq !== b.freq)
                    return b.freq - a.freq;
                return a.name.localeCompare(b.name);
            });
            return sorted.slice(0, limit);
        }
        return Fuzzy.go(q, prepared, {
            keys: keys,
            limit: limit,
            threshold: 0.2,
            scoreFn: r => {
                let s = 0;
                for (let i = 0; i < keys.length; i++)
                    s = Math.max(s, (r[i]?.score ?? 0) * weights[i]);
                return Math.min(1, s + boost(r.obj._item.freq));
            }
        }).map(r => r.obj._item);
    }

    function byId(id: string): var {
        return apps.find(a => a.id === id) ?? null;
    }

    function launch(app: var): void {
        if (!app)
            return;
        noteLaunch(app.id);

        // Prefer the desktop entry id so Path=/Exec quoting/field-codes are handled by the launcher.
        // Use a systemd *service* (not a scope): Electron apps like WhatsApp/Teams exit immediately under scopes.
        const id = app.id || "";
        if (id.length > 0) {
            Quickshell.execDetached({
                command: ["app2unit", "-t", "service", `${id}.desktop`],
                workingDirectory: Paths.home
            });
            return;
        }

        let cmd = app.command ?? app.entry?.command ?? [];
        if (!cmd || cmd.length === 0)
            return;
        // Drop freestanding desktop field codes (%U, %F, …).
        cmd = cmd.filter(a => !(typeof a === "string" && /^%[a-zA-Z]$/.test(a)));
        let wd = app.workingDirectory || "";
        const bin = String(cmd[0] ?? "");
        if (!wd && bin.includes("/")) {
            const i = bin.lastIndexOf("/");
            if (i > 0)
                wd = bin.slice(0, i);
        }
        if (!wd)
            wd = Paths.home;
        if (app.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "-t", "service", "--", "kitty", "--", ...cmd],
                workingDirectory: wd
            });
        else
            Quickshell.execDetached({
                command: ["app2unit", "-t", "service", "--", ...cmd],
                workingDirectory: wd
            });
    }

    function noteLaunch(id: string): void {
        if (!id)
            return;
        const next = Object.assign({}, frequency);
        next[id] = (next[id] ?? 0) + 1;
        frequency = next;
        revision++;
        if (freqLoaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: freqFile.setText(JSON.stringify(root.frequency, null, 2))
    }

    FileView {
        id: freqFile
        path: root.freqPath
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.frequency = parsed && typeof parsed === "object" ? parsed : {};
            } catch (e) {
                root.frequency = {};
            }
            root.freqLoaded = true;
            root.revision++;
        }
        onLoadFailed: err => {
            root.freqLoaded = true;
            if (err !== FileViewError.FileNotFound)
                console.warn("AppIndex: cannot read", path, err);
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Paths.state])
}
