pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Azure DevOps PR watcher: reads the state files written by services/git-watcher/git-watcher.py,
// supervises the daemon (systemd unit > already-running pid > self-spawned) and owns the
// mute/dismiss lists. Profile: `~/.config/quantum-moon/git-watcher.json`; when that file is
// missing but the legacy `~/.config/caelestia/git-watcher.json` exists, the caelestia
// config/state/pid paths are used read-only and a daemon alive in the legacy pid file is
// reported as `daemonState == "legacy"` (never doubled).
Singleton {
    id: root

    // -----------------------------------------------------------------------
    // Public state (read by the bar and popouts)
    // -----------------------------------------------------------------------
    property var prs: []
    property var completedPrs: []
    property var commentItems: []
    property var mentionItems: []
    property int overdueCount: 0   // raw from daemon, unfiltered
    property int mentionCount: 0   // raw from daemon, unfiltered
    property bool loading: false
    property string lastError: ""
    property string lastUpdated: ""

    property var mutedIds: []      // [prId, ...]
    property var dismissedIds: []  // [prId, ...]

    property var configData: null
    readonly property bool configured: {
        const d = configData;
        return d !== null && typeof d === "object" &&
               typeof d.pat === "string" && d.pat.length > 0 &&
               typeof d.organizationUrl === "string" && d.organizationUrl.length > 0;
    }

    readonly property bool active: !GameMode.enabled && (Config.bar.status?.showGitWatcher !== false)
    readonly property int count: prs.length

    // "systemd" | "legacy" | "external" | "self" | "stopped" | "unconfigured" | "checking"
    readonly property string daemonState: {
        if (!configured)
            return "unconfigured";
        if (systemdActive)
            return "systemd";
        if (pidAlive)
            return legacy ? "legacy" : "external";
        if (daemon.running)
            return "self";
        return checksDone ? "stopped" : "checking";
    }
    readonly property bool daemonAlive: daemonState === "systemd" || daemonState === "legacy" || daemonState === "external" || daemonState === "self"

    // -----------------------------------------------------------------------
    // Paths / profile
    // -----------------------------------------------------------------------
    readonly property string qmConfigPath: `${Paths.config}/git-watcher.json`
    readonly property string legacyConfigPath: (Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`) + "/caelestia/git-watcher.json"
    readonly property string legacyStateDir: (Quickshell.env("XDG_STATE_HOME") || `${Paths.home}/.local/state`) + "/caelestia"

    property bool qmConfigExists: false
    property bool legacyConfigExists: false
    readonly property bool legacy: !qmConfigExists && legacyConfigExists

    readonly property string configPath: legacy ? legacyConfigPath : qmConfigPath
    readonly property string stateDir: legacy ? legacyStateDir : Paths.state
    readonly property string statePath: `${stateDir}/git-watcher-state.json`
    readonly property string reposPath: `${stateDir}/git-watcher-repos.json`
    readonly property string discordPath: `${stateDir}/git-watcher-discord.json`
    readonly property string mutedPath: `${stateDir}/git-watcher-muted.json`
    readonly property string pidPath: `${stateDir}/git-watcher.pid`
    readonly property string daemonPath: `${Quickshell.shellDir}/services/git-watcher/git-watcher.py`
    readonly property string unitName: "quantum-moon-git-watcher.service"

    // -----------------------------------------------------------------------
    // Derived sets
    // -----------------------------------------------------------------------
    readonly property var _mutedSet: {
        const s = {};
        for (const id of mutedIds)
            s[id] = true;
        return s;
    }
    readonly property var _dismissedSet: {
        const s = {};
        for (const id of dismissedIds)
            s[id] = true;
        return s;
    }

    // Main feed: non-dismissed PRs + non-dismissed comments/mentions
    readonly property var mainFeedItems: {
        const items = [];
        for (const pr of prs) {
            if (_dismissedSet[pr.id])
                continue;
            items.push({
                uid: `pr-${pr.id}`,
                prId: pr.id,
                itemType: "pr",
                title: pr.title,
                repo: pr.repo,
                project: pr.project ?? "",
                url: pr.url,
                sourceBranch: pr.sourceBranch ?? "",
                targetBranch: pr.targetBranch ?? "",
                ageMinutes: pr.ageMinutes ?? 0,
                stallMinutes: pr.stallMinutes ?? 0,
                postedMinutes: pr.postedMinutes ?? -1,
                isOverdue: pr.isOverdue ?? false,
                isOwned: pr.isOwned ?? false,
                isApproved: pr.isApproved ?? false,
                hasMentions: pr.hasMentions ?? false,
                hasUnreadComments: pr.hasUnreadComments ?? false,
                isMuted: !!_mutedSet[pr.id],
                author: "",
                excerpt: ""
            });
        }
        for (const c of commentItems) {
            if (_dismissedSet[c.prId])
                continue;
            items.push({
                uid: `comment-${c.prId}-${c.author}`,
                prId: c.prId,
                itemType: "comment",
                title: c.prTitle ?? "",
                repo: c.repo ?? "",
                project: c.project ?? "",
                url: c.url,
                author: c.author ?? "",
                excerpt: c.excerpt ?? "",
                isMuted: !!_mutedSet[c.prId],
                isOverdue: false,
                hasMentions: false,
                hasUnreadComments: false,
                isOwned: false,
                targetBranch: "",
                ageMinutes: 0,
                stallMinutes: 0,
                postedMinutes: -1
            });
        }
        for (const m of mentionItems) {
            if (_dismissedSet[m.prId])
                continue;
            items.push({
                uid: `mention-${m.prId}-${m.author}`,
                prId: m.prId,
                itemType: "mention",
                title: m.prTitle ?? "",
                repo: m.repo ?? "",
                project: m.project ?? "",
                url: m.url,
                author: m.author ?? "",
                excerpt: m.excerpt ?? "",
                isMuted: !!_mutedSet[m.prId],
                isOverdue: false,
                hasMentions: false,
                hasUnreadComments: false,
                isOwned: false,
                targetBranch: "",
                ageMinutes: 0,
                stallMinutes: 0,
                postedMinutes: -1
            });
        }
        // Sort: overdue first, mentions/comments next, then by stall/age
        items.sort((a, b) => {
            const score = x => (x.isOverdue ? 8 : 0) + (x.itemType === "mention" ? 4 : 0) +
                               (x.hasMentions ? 4 : 0) + (x.itemType === "comment" ? 2 : 0) +
                               (x.hasUnreadComments ? 2 : 0);
            const diff = score(b) - score(a);
            if (diff !== 0)
                return diff;
            return (b.stallMinutes || b.ageMinutes || 0) - (a.stallMinutes || a.ageMinutes || 0);
        });
        return items;
    }

    // Archive feed: dismissed open PRs first, then completed PRs
    readonly property var archiveFeedItems: {
        const items = [];
        for (const pr of prs) {
            if (!_dismissedSet[pr.id])
                continue;
            items.push({
                uid: `arch-${pr.id}`,
                prId: pr.id,
                itemType: "pr_archived",
                title: pr.title,
                repo: pr.repo,
                project: pr.project ?? "",
                url: pr.url,
                targetBranch: pr.targetBranch ?? "",
                ageMinutes: pr.ageMinutes ?? 0,
                isOwned: pr.isOwned ?? false
            });
        }
        for (const pr of completedPrs) {
            items.push({
                uid: `comp-${pr.id}`,
                prId: pr.id,
                itemType: "pr_completed",
                title: pr.title,
                repo: pr.repo,
                project: pr.project ?? "",
                url: pr.url,
                targetBranch: pr.targetBranch ?? "",
                ageMinutes: pr.ageMinutes ?? 0,
                isOwned: pr.isOwned ?? false
            });
        }
        return items;
    }

    // Non-muted, non-dismissed items needing action
    readonly property int attentionCount: {
        let n = 0;
        for (const pr of prs) {
            if (_dismissedSet[pr.id] || _mutedSet[pr.id])
                continue;
            if (pr.isOverdue || pr.hasMentions || pr.hasUnreadComments)
                n++;
        }
        n += commentItems.filter(c => !_dismissedSet[c.prId] && !_mutedSet[c.prId]).length;
        n += mentionItems.filter(m => !_dismissedSet[m.prId] && !_mutedSet[m.prId]).length;
        return n;
    }

    readonly property int filteredOverdueCount: {
        let n = 0;
        for (const pr of prs)
            if (!_dismissedSet[pr.id] && !_mutedSet[pr.id] && (pr.isOverdue ?? false))
                n++;
        return n;
    }

    readonly property int unmutedFeedCount: mainFeedItems.filter(i => !i.isMuted).length

    readonly property color overdueColor: configData?.colors?.overdue ?? "#ff9500"
    readonly property color mentionColor: configData?.colors?.mention ?? "#e53935"
    readonly property bool discordFirst: configData?.discordFirst?.enabled ?? false

    // -----------------------------------------------------------------------
    // Mute / dismiss
    // -----------------------------------------------------------------------
    function mute(prId: int): void {
        if (!_mutedSet[prId])
            mutedIds = [...mutedIds, prId];
        _saveMuted();
    }

    function unmute(prId: int): void {
        mutedIds = mutedIds.filter(x => x !== prId);
        _saveMuted();
    }

    function dismiss(prId: int): void {
        if (!_dismissedSet[prId])
            dismissedIds = [...dismissedIds, prId];
        if (!_mutedSet[prId])   // also mute so the daemon skips notifications
            mutedIds = [...mutedIds, prId];
        _saveMuted();
    }

    function undismiss(prId: int): void {
        dismissedIds = dismissedIds.filter(x => x !== prId);
        _saveMuted();
    }

    function _saveMuted(): void {
        mutedFile.setText(JSON.stringify({ muted: mutedIds, dismissed: dismissedIds }, null, 2) + "\n");
    }

    // -----------------------------------------------------------------------
    // Config file + state files
    // -----------------------------------------------------------------------
    FileView {
        id: qmConfigProbe
        path: root.qmConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: root.qmConfigExists = true
        onLoadFailed: root.qmConfigExists = false
        onFileChanged: reload()
    }

    FileView {
        id: legacyConfigProbe
        path: root.legacyConfigPath
        watchChanges: true
        printErrors: false
        onLoaded: root.legacyConfigExists = true
        onLoadFailed: root.legacyConfigExists = false
        onFileChanged: reload()
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root.configData = JSON.parse(text());
            } catch (e) {
                console.warn("GitWatcher: config parse error:", e);
                root.configData = null;
            }
        }
        onFileChanged: reload()
        onLoadFailed: root.configData = null
        onPathChanged: reload()
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onLoaded: root._applyState(text())
        onFileChanged: reload()
        onPathChanged: reload()
    }

    FileView {
        id: mutedFile
        path: root.mutedPath
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.mutedIds = d.muted ?? [];
                root.dismissedIds = d.dismissed ?? [];
            } catch (e) {}
        }
        onFileChanged: reload()
        onPathChanged: reload()
    }

    FileView {
        id: pidFile
        path: root.pidPath
        watchChanges: true
        printErrors: false
        onLoaded: root.checkPid()
        onLoadFailed: {
            root.pidAlive = false;
            root.pidChecked = true;
        }
        onFileChanged: reload()
        onPathChanged: reload()
    }

    function _applyState(text: string): void {
        try {
            const s = JSON.parse(text);
            root.prs = s.prs ?? [];
            root.completedPrs = s.completedPrs ?? [];
            root.commentItems = s.commentItems ?? [];
            root.mentionItems = s.mentionItems ?? [];
            root.overdueCount = s.overdueCount ?? 0;
            root.mentionCount = s.mentionCount ?? 0;
            root.lastError = s.error ?? "";
            root.lastUpdated = s.lastUpdated ?? "";
            root.loading = false;
        } catch (e) {
            root.lastError = "Failed to parse state";
        }
    }

    // -----------------------------------------------------------------------
    // Daemon supervision
    // -----------------------------------------------------------------------
    property bool systemdActive: false
    property bool systemdChecked: false
    property bool pidAlive: false
    property bool pidChecked: false
    readonly property bool checksDone: systemdChecked && pidChecked

    function checkPid(): void {
        pidProc.running = true;
    }

    function checkSystemd(): void {
        systemdProc.running = true;
    }

    Process {
        id: systemdProc
        command: ["systemctl", "--user", "is-active", "--quiet", root.unitName]
        onExited: code => {
            root.systemdActive = code === 0;
            root.systemdChecked = true;
        }
    }

    Process {
        id: pidProc
        command: ["sh", "-c", 'p=$(cat "$1" 2>/dev/null); [ -n "$p" ] && kill -0 "$p" 2>/dev/null', "sh", root.pidPath]
        onExited: code => {
            root.pidAlive = code === 0;
            root.pidChecked = true;
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            root.checkSystemd();
            root.checkPid();
        }
    }

    Component.onCompleted: {
        checkSystemd();
        checkPid();
    }

    // Spawn our own daemon only when nothing else runs it: unit inactive and no live pid
    // (covers the legacy Caelestia daemon still polling the old config).
    readonly property bool shouldSpawn: active && configured && checksDone && !systemdActive && !pidAlive && (Config.get("git.spawnDaemon", true) !== false)

    onShouldSpawnChanged: {
        if (shouldSpawn && !daemon.running)
            spawnDelay.restart();
    }

    Timer {
        id: spawnDelay
        interval: 1500
        onTriggered: {
            if (root.shouldSpawn && !daemon.running) {
                console.log(`GitWatcher: spawning daemon (${root.legacy ? "legacy" : "quantum-moon"} profile)`);
                daemon.running = true;
            }
        }
    }

    Process {
        id: daemon
        command: ["python3", root.daemonPath]
        environment: ({ QM_SHELL_IPC: "qs -c quantum-moon ipc call" })
        stderr: SplitParser {
            onRead: line => console.log("git-watcher:", line)
        }
        onExited: (code, status) => {
            console.warn(`GitWatcher: daemon exited (${code})`);
            root.checkPid();
            if (root.shouldSpawn)
                restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 5000
        onTriggered: {
            if (root.shouldSpawn && !daemon.running)
                daemon.running = true;
        }
    }

    // -----------------------------------------------------------------------
    // Manual refresh (SIGHUP via pid file)
    // -----------------------------------------------------------------------
    function refresh(): void {
        loading = true;
        sighupProc.running = true;
        loadingFallback.restart();
    }

    Process {
        id: sighupProc
        command: ["sh", "-c", 'p=$(cat "$1" 2>/dev/null); [ -n "$p" ] && kill -HUP "$p"', "sh", root.pidPath]
        onExited: code => {
            if (code !== 0)
                root.loading = false;
        }
    }

    Timer {
        id: loadingFallback
        interval: 8000
        onTriggered: root.loading = false
    }

    // -----------------------------------------------------------------------
    // Config window (modules/bar/popouts/GitWatcherConfig.qml, a PanelWindow)
    // -----------------------------------------------------------------------
    property bool configOpen: false

    function openConfig(): void {
        configOpen = true;
    }

    function closeConfig(): void {
        configOpen = false;
    }

    LazyLoader {
        activeAsync: root.configOpen
        source: `${Quickshell.shellDir}/modules/bar/popouts/GitWatcherConfig.qml`
    }

    // Always writes the quantum-moon config (migrates a legacy profile), then nudges the daemon:
    // start the unit when it is not active, SIGHUP whatever pid file the new profile has.
    function applyConfig(jsonText: string): void {
        qmConfigWriter.setText(jsonText.endsWith("\n") ? jsonText : jsonText + "\n");
        applyNudge.restart();
    }

    FileView {
        id: qmConfigWriter
        path: root.qmConfigPath
        printErrors: false
        atomicWrites: true
        onSaved: {
            chmodProc.running = true;
            root.qmConfigExists = true;
        }
        onSaveFailed: err => console.warn("GitWatcher: config write failed:", err)
    }

    Process {
        id: chmodProc
        command: ["chmod", "600", root.qmConfigPath]
    }

    Timer {
        id: applyNudge
        interval: 400
        onTriggered: applyProc.running = true
    }

    Process {
        id: applyProc
        command: ["sh", "-c",
            'systemctl --user is-active --quiet "$1" || systemctl --user start "$1" 2>/dev/null; ' +
            'p=$(cat "$2" 2>/dev/null); [ -n "$p" ] && kill -HUP "$p" 2>/dev/null; true',
            "sh", root.unitName, root.pidPath]
        onExited: {
            root.checkSystemd();
            root.checkPid();
        }
    }

    IpcHandler {
        target: "git"

        function refresh(): void {
            root.refresh();
        }

        function open(): void {
            root.openConfig();
        }

        function state(): string {
            return root.daemonState;
        }

        // Open the bar popout (sticky) on the main screen, anchored near the status segment.
        function popout(): void {
            root.showPopout();
        }
    }

    function showPopout(): void {
        const host = Visibilities.popoutFor(Screens.mainName);
        if (!host)
            return;
        const w = host.width;
        host.show("gitwatcher", w - 260, 40, null, true);
    }
}
