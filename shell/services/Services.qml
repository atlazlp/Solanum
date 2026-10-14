pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Local service stack (Docker / Ollama / Open WebUI) status + actions, and the `services.json`
// config shared with KvmCapture. Polls 10 s while a panel holds a ref, 60 s otherwise.
Singleton {
    id: root

    // ---- config (~/.config/quantum-moon/services.json) ----
    readonly property var defaults: ({
            llm: {
                controlScript: `${Paths.home}/Projects/gemma4-heretic/llm-control.sh`,
                ollamaUrl: "http://127.0.0.1:11434",
                webuiUrl: "http://127.0.0.1:8080",
                composeDir: `${Paths.home}/Projects/gemma4-heretic`
            },
            kvm: {
                launchScript: `${Paths.home}/Projects/lan-kvm-hyprland/arch-hyprland/scripts/lan-mouse-launch.sh`,
                clipboardScript: `${Paths.home}/Projects/lan-kvm-hyprland/scripts/clipboard-sync.sh`,
                logPath: `${Paths.home}/.local/state/lan-kvm-hyprland/uniclip.log`,
                peersConfig: `${Paths.home}/.config/lan-mouse/config.toml`
            }
        })
    property var user: ({})
    readonly property var llm: Object.assign({}, defaults.llm, user.llm ?? {})
    readonly property var kvm: Object.assign({}, defaults.kvm, user.kvm ?? {})
    readonly property bool configLoaded: cfgFile.loaded

    function expand(p: string): string {
        return (p ?? "").replace(/^~/, Paths.home);
    }

    // ---- polling ----
    property int refs: 0                       // bumped by open panels
    readonly property int interval: refs > 0 ? 10000 : 60000
    property bool refreshing: false
    property double lastRefresh: 0

    // ---- status ----
    property string ollamaSystemUnit: "unknown"     // systemctl is-active ollama
    property string ollamaUserUnit: "unknown"       // systemctl --user is-active ollama
    property string ollamaVersion: ""
    readonly property bool ollamaUp: ollamaVersion.length > 0
    property list<var> ollamaModels: []             // { name, size, vram, expires }
    property bool dockerUp: false
    property string dockerVersion: ""
    property var webuiContainer: null               // docker ps -a json for open-webui, or null
    readonly property bool webuiRunning: !!webuiContainer && (webuiContainer.State === "running")
    property int webuiHttp: 0
    readonly property bool webuiUp: webuiRunning || (webuiHttp >= 200 && webuiHttp < 500)
    readonly property bool stackOn: ollamaUp && webuiUp
    readonly property bool stackPartial: !stackOn && (ollamaUp || webuiUp)

    // ---- actions ----
    property string busy: ""                        // "start" | "stop" | "open" | "restart-ollama" | "unload" | ""
    property string error: ""

    signal refreshed()

    function refresh(): void {
        if (statusProc.running)
            return;
        refreshing = true;
        statusProc.running = true;
    }

    function run(action: string): void {
        if (actionProc.running) {
            Toaster.toast("Services busy", `Still running "${busy}"`, "hourglass_top", "warn", 0);
            return;
        }
        error = "";
        busy = action;
        actionProc.command = ["sh", "-c", `if [ -x "$1" ]; then exec "$1" "$2"; else echo "control script missing: $1" >&2; exit 127; fi`, "qm-llm", expand(llm.controlScript), action];
        actionProc.running = true;
    }

    function llmStart(): void {
        run("start");
    }

    function llmStop(): void {
        run("stop");
    }

    function llmToggle(): void {
        run(stackOn ? "stop" : "start");
    }

    function restartOllama(): void {
        run("restart-ollama");
    }

    function openWebui(): void {
        if (webuiUp) {
            Quickshell.execDetached(["xdg-open", llm.webuiUrl]);
            return;
        }
        run("open");
    }

    function unloadModel(name: string): void {
        if (unloadProc.running)
            return;
        error = "";
        busy = "unload";
        unloadProc.command = ["curl", "-sf", "--noproxy", "*", "--connect-timeout", "2", "-X", "POST", `${llm.ollamaUrl}/api/generate`, "-d", JSON.stringify({
                model: name,
                keep_alive: 0
            })];
        unloadProc.running = true;
    }

    function fail(title: string, msg: string): void {
        error = msg;
        Toaster.toast(title, msg, "error", "error", 0);
    }

    function fmtBytes(b: real): string {
        if (!b || b <= 0)
            return "0 B";
        const u = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return `${b.toFixed(i >= 3 ? 1 : 0)} ${u[i]}`;
    }

    function parseStatus(text: string): void {
        let sys = "unknown", usr = "unknown", ver = "", models = [], docker = false, dver = "", webui = null, http = 0;
        for (const line of text.split("\n")) {
            const sp = line.indexOf(" ");
            const key = sp < 0 ? line : line.slice(0, sp);
            const val = sp < 0 ? "" : line.slice(sp + 1).trim();
            switch (key) {
            case "SYS":
                sys = val || "unknown";
                break;
            case "USER":
                usr = val || "unknown";
                break;
            case "VER":
                try {
                    ver = val ? (JSON.parse(val).version ?? "") : "";
                } catch (e) {
                    ver = "";
                }
                break;
            case "PS":
                try {
                    const ps = val ? JSON.parse(val) : {};
                    for (const m of ps.models ?? [])
                        models.push({
                            name: m.name ?? m.model ?? "?",
                            size: m.size ?? 0,
                            vram: m.size_vram ?? 0,
                            expires: m.expires_at ?? "",
                            family: m.details?.family ?? "",
                            params: m.details?.parameter_size ?? "",
                            quant: m.details?.quantization_level ?? ""
                        });
                } catch (e) {
                    models = [];
                }
                break;
            case "DOCKER":
                docker = val.length > 0;
                dver = val;
                break;
            case "WEBUI":
                try {
                    webui = val ? JSON.parse(val) : null;
                } catch (e) {
                    webui = null;
                }
                break;
            case "HTTP":
                http = parseInt(val) || 0;
                break;
            }
        }
        ollamaSystemUnit = sys;
        ollamaUserUnit = usr;
        ollamaVersion = ver;
        ollamaModels = models;
        dockerUp = docker;
        dockerVersion = dver;
        webuiContainer = webui;
        webuiHttp = http;
        lastRefresh = Date.now();
        refreshing = false;
        refreshed();
    }

    Component.onCompleted: refresh()
    onIntervalChanged: refresh()

    FileView {
        id: cfgFile

        path: `${Paths.config}/services.json`
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root.user = JSON.parse(text());
            } catch (e) {
                console.warn("Services: invalid services.json", e);
                root.user = {};
            }
        }
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("Services: could not load", path, err);
            root.user = {};
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc

        command: ["sh", "-c", `
O="$1"; W="$2"
echo "SYS $(systemctl is-active ollama 2>/dev/null)"
echo "USER $(systemctl --user is-active ollama 2>/dev/null)"
echo "VER $(curl -sf --noproxy '*' --connect-timeout 1 --max-time 3 "$O/api/version" 2>/dev/null)"
echo "PS $(curl -sf --noproxy '*' --connect-timeout 1 --max-time 3 "$O/api/ps" 2>/dev/null)"
DV="$(timeout 4 docker info --format '{{.ServerVersion}}' 2>/dev/null)"
echo "DOCKER $DV"
if [ -n "$DV" ]; then echo "WEBUI $(timeout 4 docker ps -a --format '{{json .}}' --filter name=open-webui 2>/dev/null | head -n 1)"; fi
echo "HTTP $(curl -s --noproxy '*' --connect-timeout 1 --max-time 3 -o /dev/null -w '%{http_code}' "$W" 2>/dev/null)"
`, "qm-services", root.llm.ollamaUrl, root.llm.webuiUrl]
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
            const action = root.busy;
            if (exitCode !== 0) {
                const msg = actionErr.text.trim().split("\n").pop() || `exit ${exitCode}`;
                root.fail(`LLM ${action} failed`, msg);
            } else if (action === "start" || action === "stop" || action === "restart-ollama") {
                Toaster.toast("LLM stack", action === "stop" ? "Stack stopped" : (action === "start" ? "Stack started" : "Ollama restarted"), "smart_toy", "success", 0);
            }
            root.refresh();
        }
    }

    Process {
        id: unloadProc

        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0)
                root.fail("Unload failed", `curl exit ${exitCode}`);
            root.refresh();
        }
    }

    // busy clears once the first refresh after the action lands
    onRefreshed: {
        if (busy && !actionProc.running && !unloadProc.running)
            busy = "";
    }

    IpcHandler {
        target: "services"

        function refresh(): void {
            root.refresh();
        }

        function llm(action: string): string {
            if (action !== "start" && action !== "stop")
                return "usage: llm start|stop";
            root.run(action);
            return action;
        }

        function openWebui(): void {
            root.openWebui();
        }

        function status(): string {
            return root.stackOn ? "on" : (root.stackPartial ? "partial" : "off");
        }
    }
}
