pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Set by the KVM daemon while the keyboard/mouse are captured by another machine:
// every drawer closes and hover strips are disabled until capture ends.
Singleton {
    id: root

    property bool active: false
    property bool daemon: false
    property bool clipboard: false

    function setActive(on: bool): void {
        if (root.active === on)
            return;
        root.active = on;
        if (on)
            Visibilities.closeAll();
    }

    // ---- daemon / clipboard status + actions (scripts from Services.kvm, services.json) ----
    property int refs: 0                              // bumped by the KVM panel: 5 s polling, else 30 s
    readonly property int interval: refs > 0 ? 5000 : 30000
    property bool refreshing: false
    property bool daemonKnown: false                  // first status poll landed
    property string busy: ""                          // "daemon-start" | "daemon-stop" | "clip-start" | "clip-stop" | ""
    property string error: ""
    property list<string> logLines: []                // last lines of the uniclip log
    property list<var> peers: []                      // { hostname, ips, position, active } from lan-mouse config.toml
    property string launchScript: Services.expand(Services.kvm.launchScript)
    property string clipboardScript: Services.expand(Services.kvm.clipboardScript)
    property string logPath: Services.expand(Services.kvm.logPath)
    property string peersConfig: Services.expand(Services.kvm.peersConfig)

    signal refreshed()

    function refresh(): void {
        if (statusProc.running)
            return;
        refreshing = true;
        statusProc.running = true;
    }

    function runAction(id: string, script: string, arg: string): void {
        if (actionProc.running) {
            Toaster.toast("KVM busy", `Still running "${busy}"`, "hourglass_top", "warn", 0);
            return;
        }
        error = "";
        busy = id;
        actionProc.command = ["sh", "-c", `if [ -x "$1" ]; then exec "$1" "$2"; else echo "script missing: $1" >&2; exit 127; fi`, "qm-kvm", script, arg];
        actionProc.running = true;
    }

    function startDaemon(): void {
        runAction("daemon-start", launchScript, "start");
    }

    function stopDaemon(): void {
        runAction("daemon-stop", launchScript, "stop");
    }

    function startClipboard(): void {
        runAction("clip-start", clipboardScript, "start");
    }

    function stopClipboard(): void {
        runAction("clip-stop", clipboardScript, "stop");
    }

    function openGui(): void {
        Quickshell.execDetached(["sh", "-c", `exec "$1" gui`, "qm-kvm-gui", launchScript]);
    }

    function restoreHovers(): void {
        setActive(false);
    }

    // Minimal TOML: [[clients]] tables with hostname / ips / position / activate_on_startup.
    function parsePeers(text: string): var {
        const out = [];
        let cur = null;
        for (const raw of text.split("\n")) {
            const line = raw.replace(/#.*$/, "").trim();
            if (!line)
                continue;
            if (/^\[\[clients\]\]$/.test(line)) {
                cur = { hostname: "", ips: [], position: "", active: false };
                out.push(cur);
                continue;
            }
            if (/^\[/.test(line)) {
                cur = null;
                continue;
            }
            if (!cur)
                continue;
            const m = line.match(/^([A-Za-z_]+)\s*=\s*(.*)$/);
            if (!m)
                continue;
            const key = m[1], val = m[2].trim();
            if (key === "hostname" || key === "position")
                cur[key] = val.replace(/^"|"$/g, "");
            else if (key === "ips")
                cur.ips = (val.match(/"([^"]*)"/g) ?? []).map(s => s.replace(/"/g, ""));
            else if (key === "activate_on_startup")
                cur.active = val === "true";
        }
        return out;
    }

    function parseStatus(text: string): void {
        const lines = text.split("\n");
        let d = false, c = false, log = [], peersText = "", section = "";
        for (const line of lines) {
            if (line === "::DAEMON" || line === "::CLIP" || line === "::LOG" || line === "::PEERS") {
                section = line.slice(2);
                continue;
            }
            switch (section) {
            case "DAEMON":
                d = line.trim() === "on";
                break;
            case "CLIP":
                c = line.trim() === "on";
                break;
            case "LOG":
                if (line.length)
                    log.push(line);
                break;
            case "PEERS":
                peersText += line + "\n";
                break;
            }
        }
        daemon = d;
        clipboard = c;
        logLines = log.slice(-5);
        peers = parsePeers(peersText);
        daemonKnown = true;
        refreshing = false;
        refreshed();
    }

    Component.onCompleted: refresh()
    onIntervalChanged: refresh()

    Timer {
        interval: root.interval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc

        command: ["sh", "-c", `
L="$1"; C="$2"; LOG="$3"; P="$4"
echo "::DAEMON"; [ -x "$L" ] && timeout 4 "$L" status 2>/dev/null || echo off
echo "::CLIP"; [ -x "$C" ] && timeout 4 "$C" status 2>/dev/null || echo off
echo "::LOG"; [ -f "$LOG" ] && tail -n 5 "$LOG" 2>/dev/null
echo "::PEERS"; [ -f "$P" ] && cat "$P" 2>/dev/null
`, "qm-kvm-status", root.launchScript, root.clipboardScript, root.logPath, root.peersConfig]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
        onExited: root.refreshing = false
    }

    Process {
        id: actionProc

        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: actionErr
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                const msg = actionErr.text.trim().split("\n").pop() || `exit ${exitCode}`;
                root.error = msg;
                Toaster.toast(`KVM ${root.busy} failed`, msg, "error", "error", 0);
            }
            root.refresh();
        }
    }

    onRefreshed: {
        if (busy && !actionProc.running)
            busy = "";
    }

    IpcHandler {
        target: "kvm"

        function capture(on: bool): void {
            root.setActive(on);
        }

        function isCaptured(): bool {
            return root.active;
        }

        function daemon(on: bool): void {
            root.daemon = on;
        }

        function clipboard(on: bool): void {
            root.clipboard = on;
        }
    }
}
