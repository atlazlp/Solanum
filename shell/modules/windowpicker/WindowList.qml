pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils
import qs.modules.launcher.items

// List of Hyprland toplevels (steam ghost windows filtered out) with cleaned titles, class and RAM
// (`ps` every 2 s while `active`). `grouped` adds a workspace header per section. Rows are
// launcher WindowItem rows; the owner handles focusRequested / killRequested / editRequested.
NomaiList {
    id: root

    property string query: ""
    property bool grouped: true
    property bool active: true
    property int maxShown: Config.launcher.maxShown ?? 10
    readonly property int rowHeight: 44
    property bool revealing: false
    property bool hoverSelects: true
    property int wantedIndex: 0

    signal focusRequested(var row)
    signal killRequested(var row)
    signal editRequested(var target)

    property var memoryByPid: ({})
    property int memoryRev: 0

    readonly property var knownSuffixes: new Set(["mozilla firefox", "firefox", "librewolf", "waterfox", "google chrome", "chromium", "chromium browser", "microsoft edge", "msedge", "brave", "brave browser", "tor browser", "safari", "cursor", "visual studio code", "code", "vscodium", "github desktop", "thunar", "nautilus", "pcmanfm", "nemo", "gedit", "kate", "foot", "kitty", "alacritty", "wezterm"])

    function formatHyprAddress(addr): string {
        if (addr === undefined || addr === null)
            return "";
        if (typeof addr === "number" && Number.isFinite(addr))
            return `0x${Math.trunc(addr).toString(16)}`;
        let s = String(addr).trim();
        if (!s)
            return "";
        if (s.startsWith("0x") || s.startsWith("0X"))
            return `0x${s.slice(2).toLowerCase()}`;
        return `0x${s.toLowerCase()}`;
    }

    // ProtonGhosts: steam_app_* / steam_proton windows with an empty title and a tiny size.
    function isGhost(lo: var): bool {
        const klass = (lo.class ?? lo.initialClass ?? "").toString().trim();
        if (!(klass.startsWith("steam_app_") || klass === "steam_proton"))
            return false;
        if ((lo.title ?? lo.initialTitle ?? "").toString().trim())
            return false;
        const sz = lo.size;
        if (!Array.isArray(sz) || sz.length < 2)
            return false;
        const w = Number(sz[0]), h = Number(sz[1]);
        if (!(w > 0) && !(h > 0))
            return false;
        return h <= 30 && w <= 220;
    }

    function isListable(c: var): bool {
        const lo = c?.lastIpcObject;
        if (!lo || isGhost(lo))
            return false;
        if (lo.mapped === false || lo.hidden === true)
            return false;
        if (!formatHyprAddress(c.address))
            return false;
        const sz = lo.size;
        if (Array.isArray(sz) && sz[0] === 0 && sz[1] === 0)
            return false;
        const klass = (lo.class ?? lo.initialClass ?? "").toString().trim();
        const title = (lo.title ?? lo.initialTitle ?? "").toString().trim();
        return !!(klass || title);
    }

    function stripTrailingAppSegments(rawTitle, klass): string {
        const t = (rawTitle ?? "").toString().trim();
        if (!t)
            return "";
        const klassKey = (klass ?? "").toString().trim().toLowerCase();
        const klassSpaced = klassKey.replace(/-/g, " ");
        const parts = t.split(/\s+[\-–—]\s+/).map(p => p.trim()).filter(p => p.length);
        if (parts.length < 2)
            return t;
        const noise = seg => {
            const s = seg.trim().toLowerCase();
            return !!s && (knownSuffixes.has(s) || (klassKey && (s === klassKey || s === klassSpaced)));
        };
        while (parts.length >= 2 && noise(parts[parts.length - 1]))
            parts.pop();
        return parts.length ? parts.join(" - ") : t;
    }

    function formatRam(kb: int): string {
        if (!kb || kb <= 0)
            return "";
        const mib = kb / 1024;
        if (mib >= 1024)
            return `${(mib / 1024).toFixed(1)} GB`;
        if (mib >= 10)
            return `${Math.round(mib)} MB`;
        return `${mib.toFixed(1)} MB`;
    }

    function wsLabelOf(lo: var): string {
        const ws = lo.workspace ?? {};
        const name = (ws.name ?? "").toString();
        if (name.startsWith("special:"))
            return name.slice(8) || "special";
        if (name)
            return `Workspace ${name}`;
        return `Workspace ${ws.id ?? "?"}`;
    }

    readonly property list<var> rows: {
        const _r = LauncherItemOverrides.revision;
        const words = (query ?? "").toLowerCase().split(/\s+/).filter(w => w);
        const vals = Hypr.toplevels?.values ?? [];
        let out = vals.filter(isListable).map(c => {
            const lo = c.lastIpcObject;
            const klass = (lo.class ?? lo.initialClass ?? "").toString().trim();
            const rawTitle = (lo.title ?? lo.initialTitle ?? "").toString().trim();
            let rawLine = rawTitle ? stripTrailingAppSegments(rawTitle, klass) : "";
            if (!rawLine)
                rawLine = klass || "?";
            const line = LauncherItemOverrides.displayLabel("window", klass, rawLine);
            const subtitle = LauncherItemOverrides.subtitle("window", klass, klass);
            const pid = typeof lo.pid === "number" ? lo.pid : parseInt(lo.pid, 10) || 0;
            const ws = lo.workspace ?? {};
            return {
                address: formatHyprAddress(c.address),
                pid: pid,
                line: line,
                rawLine: rawLine,
                klass: klass,
                subtitle: subtitle,
                title: rawTitle,
                wsId: Number(ws.id ?? 0),
                wsLabel: wsLabelOf(lo),
                focusOrder: Number(lo.focusHistoryID ?? 9999),
                icon: Icons.getAppIcon(klass, ""),
                searchText: `${klass} ${rawTitle} ${line} ${subtitle}`.toLowerCase()
            };
        });
        if (words.length)
            out = out.filter(r => words.every(w => r.searchText.includes(w)));
        if (!grouped) {
            out.sort((a, b) => a.focusOrder - b.focusOrder);
            return out;
        }
        out.sort((a, b) => a.wsId !== b.wsId ? a.wsId - b.wsId : a.focusOrder - b.focusOrder);
        // Workspace headers are pseudo-rows (ScriptModel has no role for ListView sections).
        const withHeaders = [];
        let lastWs = null;
        for (const r of out) {
            if (r.wsId !== lastWs) {
                withHeaders.push({ header: true, wsLabel: r.wsLabel, wsId: r.wsId, address: "", pid: 0 });
                lastWs = r.wsId;
            }
            withHeaders.push(r);
        }
        return withHeaders;
    }

    readonly property int windowCount: rows.filter(r => !r.header).length

    function ramLabelFor(pid: int): string {
        const _m = memoryRev;
        return pid > 0 ? formatRam(memoryByPid[pid] ?? 0) : "";
    }

    // Clamp + skip header rows in direction `dir` (falls back to the other direction at the ends).
    function select(i: int, dir: int): void {
        const d = dir === -1 ? -1 : 1;
        const n = count;
        if (n === 0)
            return;
        i = Math.max(0, Math.min(i, n - 1));
        let j = i;
        while (j >= 0 && j < n && rows[j]?.header)
            j += d;
        if (j < 0 || j >= n) {
            j = i;
            while (j >= 0 && j < n && rows[j]?.header)
                j -= d;
        }
        if (j < 0 || j >= n)
            j = i;
        wantedIndex = j;
        currentIndex = j;
    }

    function moveBy(delta: int): void {
        if (count === 0)
            return;
        let i = currentIndex + delta;
        if (Math.abs(delta) === 1)
            i = (i + count) % count;
        select(i, delta < 0 ? -1 : 1);
    }

    function activateCurrent(): void {
        const row = rows[currentIndex];
        if (row && !row.header)
            focusRequested(row);
    }

    function killCurrent(): void {
        const row = rows[currentIndex];
        if (row && !row.header)
            killRequested(row);
    }

    function editCurrent(): void {
        const item = currentItem;
        if (item && typeof item.editTarget === "function")
            editRequested(item.editTarget());
    }

    function revealNow(): void {
        revealing = true;
        for (const c of contentItem.children)
            if (typeof c.reveal === "function")
                c.reveal();
        revealTimer.restart();
    }

    Timer {
        id: revealTimer
        interval: Motion.panelOpen + Motion.glyphStagger * Motion.glyphStaggerMax
        onTriggered: root.revealing = false
    }

    model: ScriptModel {
        values: root.rows
        onValuesChanged: Qt.callLater(() => root.select(root.wantedIndex, 1))
    }

    onQueryChanged: wantedIndex = 0

    delegate: WindowItem {
        onFocusRequested: row => root.focusRequested(row)
        onKillRequested: row => root.killRequested(row)
        onEditRequested: target => root.editRequested(target)
    }

    implicitHeight: Math.max(rowHeight, Math.min(contentHeight, maxShown * (rowHeight + spacing) - spacing))

    GlyphText {
        anchors.centerIn: parent
        visible: root.count === 0
        text: root.query ? "No matching windows" : "No windows"
        dim: true
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: memProc.running = true
    }

    Process {
        id: memProc
        command: ["ps", "-eo", "pid=,rss="]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 2)
                        continue;
                    const pid = parseInt(parts[0], 10);
                    const kb = parseInt(parts[1], 10);
                    if (pid > 0 && kb >= 0)
                        map[pid] = kb;
                }
                root.memoryByPid = map;
                root.memoryRev++;
            }
        }
    }
}
