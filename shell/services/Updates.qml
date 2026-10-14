pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Pending package updates via `qm-update --check` ({"repo":N,"aur":M,"packages":[{name,from,to,source}]}).
// Checks every Config.updates.interval seconds, on logind resume and on refresh(); the last result is
// cached in ~/.cache/quantum-moon/updates.json so the bar shows a count right after a reload.
Singleton {
    id: root

    property int count: 0
    property int repoCount: 0
    property int aurCount: 0
    property bool checking: false
    property list<var> packages: []
    property string lastChecked: ""
    property string lastError: ""

    readonly property list<var> repoPackages: packages.filter(p => p.source !== "aur")
    readonly property list<var> aurPackages: packages.filter(p => p.source === "aur")

    readonly property string cachePath: `${Paths.cache}/updates.json`
    readonly property string fallbackCommand: `${Quickshell.shellDir}/../bin/qm-update`
    // ~/.local/bin/qm-update when installed, else the repo copy; Config.updates.command overrides both.
    readonly property string resolveScript: 'u="$HOME/.local/bin/qm-update"; [ -n "$1" ] && u="$1"; [ -x "$u" ] || u="$2"; exec "$u"'

    function refresh(): void {
        if (checking)
            return;
        checking = true;
        lastError = "";
        checkProc.running = true;
    }

    function run(): void {
        Quickshell.execDetached(["sh", "-c", `${resolveScript}`, "sh", Config.updates.command ?? "", fallbackCommand]);
    }

    function applyResult(text: string, fromCache: bool): void {
        try {
            const d = JSON.parse(text);
            const pkgs = Array.isArray(d.packages) ? d.packages : [];
            const prev = count;
            const hadBaseline = hasChecked;
            packages = pkgs;
            repoCount = d.repo ?? pkgs.filter(p => p.source !== "aur").length;
            aurCount = d.aur ?? pkgs.filter(p => p.source === "aur").length;
            count = pkgs.length;
            lastChecked = d.checkedAt ?? new Date().toISOString();
            if (!fromCache) {
                cacheFile.setText(JSON.stringify({ repo: repoCount, aur: aurCount, packages: pkgs, checkedAt: lastChecked }) + "\n");
                if (count !== prev && hadBaseline && Config.updates.toast !== false)
                    Toaster.toast("Updates", count > 0 ? `${count} package${count === 1 ? "" : "s"} pending (${repoCount} repo, ${aurCount} AUR)` : "System is up to date", "system_update_alt", count > 0 ? "info" : "success", 0);
            }
            hasChecked = true;
        } catch (e) {
            lastError = `bad output: ${e}`;
            console.warn("Updates: parse error:", e, text.slice(0, 200));
        }
    }

    property bool hasChecked: false

    Process {
        id: checkProc
        command: ["sh", "-c", `${root.resolveScript} --check`, "sh", Config.updates.command ?? "", root.fallbackCommand]
        stdout: StdioCollector {
            onStreamFinished: root.applyResult(text, false)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.warn("Updates: qm-update stderr:", text.trim().slice(0, 300));
            }
        }
        onExited: code => {
            root.checking = false;
            if (code !== 0)
                root.lastError = `qm-update exited ${code}`;
        }
    }

    FileView {
        id: cacheFile
        path: root.cachePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (!root.hasChecked)
                root.applyResult(text(), true);
        }
    }

    Timer {
        interval: Math.max(60, Config.updates.interval ?? 1800) * 1000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    Timer {
        // First check shortly after start, after the cache has been applied.
        interval: 4000
        running: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Logind
        ignoreUnknownSignals: true
        function onResumed(): void {
            if (Config.updates.checkOnResume !== false)
                resumeDelay.restart();
        }
    }

    Timer {
        id: resumeDelay
        interval: 20000   // let the network come back first
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh();
        }

        function run(): void {
            root.run();
        }

        function count(): int {
            return root.count;
        }

        // Open the bar popout (sticky) on the main screen.
        function popout(): void {
            root.showPopout();
        }
    }

    function showPopout(): void {
        const host = Visibilities.popoutFor(Screens.mainName);
        if (!host)
            return;
        host.show("updates", host.width - 230, 40, null, true);
    }
}
