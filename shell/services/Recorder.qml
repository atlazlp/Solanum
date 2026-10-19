pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// gpu-screen-recorder control, pid-file compatible with bin/qm-record:
//   $XDG_RUNTIME_DIR/solanum-record.pid  (pid of gpu-screen-recorder)
//   $XDG_RUNTIME_DIR/solanum-record.path (output file)
// Modes: screen | region | screen-audio | region-audio ("+audio" / "_audio" also accepted).
// pause = SIGUSR2 (toggle), stop = SIGINT (file is finalised).
Singleton {
    id: root

    property bool running: false
    property bool paused: false
    property string mode: ""
    property string file: ""
    property int pid: 0
    property real elapsed: 0          // seconds
    property bool busy: false

    readonly property list<var> modes: [
        { id: "screen", icon: "desktop_windows", label: "Screen" },
        { id: "region", icon: "crop", label: "Region" },
        { id: "screen-audio", icon: "speaker_notes", label: "Screen + audio" },
        { id: "region-audio", icon: "settings_voice", label: "Region + audio" }
    ]

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string pidFile: `${runtimeDir}/solanum-record.pid`
    readonly property string pathFile: `${runtimeDir}/solanum-record.path`
    readonly property string outDir: (Quickshell.env("XDG_VIDEOS_DIR") || `${Quickshell.env("HOME")}/Videos`) + "/Recordings"
    readonly property int fps: Config.utilities.recorder?.fps ?? 60
    readonly property string audioSource: Config.utilities.recorder?.audioSource ?? "default_output"

    function normalizeMode(m: string): string {
        m = (m ?? "").toLowerCase().replace(/[+_ ]/g, "-");
        const region = m.startsWith("region") || m.startsWith("area");
        const audio = m.includes("audio") || m.includes("sound");
        return (region ? "region" : "screen") + (audio ? "-audio" : "");
    }

    function start(m: string): string {
        if (running || busy)
            return "already running";
        const nm = normalizeMode(m);
        mode = nm;
        busy = true;
        if (nm.startsWith("region")) {
            slurp.running = true;
        } else {
            launch(Hypr.focusedMonitor?.name ?? "screen", "");
        }
        return "ok";
    }

    function launch(target: string, region: string): void {
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        const out = `${outDir}/${ts}.mp4`;
        const args = ["-f", String(fps), "-o", out, "-w", target];
        if (region)
            args.push("-region", region);
        if (mode.endsWith("audio"))
            args.push("-a", audioSource);
        launcher.outFile = out;
        launcher.args = args;
        launcher.running = true;
    }

    function stop(): void {
        if (!running || pid <= 0) {
            clearState();
            return;
        }
        Quickshell.execDetached(["sh", "-c", `kill -INT ${pid} 2>/dev/null; rm -f "${pidFile}" "${pathFile}"`]);
        const name = file.split("/").pop();
        clearState();
        Toaster.toast("Recording stopped", name, "videocam_off", "success", 0);
    }

    function togglePause(): void {
        if (!running || pid <= 0)
            return;
        Quickshell.execDetached(["kill", "-USR2", String(pid)]);
        paused = !paused;
        Toaster.toast(paused ? "Recording paused" : "Recording resumed", "", paused ? "pause_circle" : "play_circle", "info", 0);
    }

    function clearState(): void {
        running = false;
        paused = false;
        pid = 0;
        file = "";
        elapsed = 0;
    }

    function check(): void {
        if (!checkProc.running)
            checkProc.running = true;
    }

    Process {
        id: slurp

        command: ["slurp", "-f", "%wx%h+%x+%y"]
        onExited: code => {
            if (code !== 0) {
                root.busy = false;
                root.mode = "";
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const geom = text.trim();
                if (geom)
                    root.launch("region", geom);
            }
        }
    }

    Process {
        id: launcher

        property string outFile: ""
        property list<string> args: []

        command: ["sh", "-c", `
mkdir -p "$OUTDIR" || exit 1
command -v gpu-screen-recorder >/dev/null 2>&1 || { echo "missing"; exit 1; }
setsid gpu-screen-recorder "$@" >/dev/null 2>&1 </dev/null &
pid=$!
echo "$pid" > "$PIDFILE"
echo "$OUTFILE" > "$PATHFILE"
sleep 0.6
if kill -0 "$pid" 2>/dev/null; then echo "$pid"; else rm -f "$PIDFILE" "$PATHFILE"; echo "dead"; exit 1; fi
`, "qm-record", ...args]
        environment: ({ OUTDIR: root.outDir, OUTFILE: outFile, PIDFILE: root.pidFile, PATHFILE: root.pathFile })
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                const out = text.trim();
                const p = parseInt(out, 10);
                if (!isNaN(p) && p > 0) {
                    root.pid = p;
                    root.file = launcher.outFile;
                    root.running = true;
                    root.paused = false;
                    root.elapsed = 0;
                    Toaster.toast("Recording started", launcher.outFile.split("/").pop(), "screen_record", "info", 0);
                } else {
                    root.mode = "";
                    Toaster.toast("Recording failed", out === "missing" ? "gpu-screen-recorder is not installed" : "gpu-screen-recorder exited immediately", "videocam_off", "error", 0);
                }
            }
        }
    }

    // Liveness: picks up recordings started by bin/qm-record and notices external stops.
    Process {
        id: checkProc

        command: ["sh", "-c", `
[ -f "$PIDFILE" ] || { echo none; exit 0; }
pid=$(cat "$PIDFILE" 2>/dev/null)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo "$pid"; cat "$PATHFILE" 2>/dev/null; else rm -f "$PIDFILE" "$PATHFILE"; echo none; fi
`]
        environment: ({ PIDFILE: root.pidFile, PATHFILE: root.pathFile })
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const p = parseInt(lines[0], 10);
                if (isNaN(p) || p <= 0) {
                    if (root.running)
                        root.clearState();
                    return;
                }
                if (!root.running) {
                    root.pid = p;
                    root.file = lines[1] ?? "";
                    root.running = true;
                    root.paused = false;
                    if (!root.mode)
                        root.mode = "screen";
                }
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: root.running ? 2000 : 5000
        triggeredOnStart: true
        onTriggered: root.check()
    }

    Timer {
        running: root.running && !root.paused
        repeat: true
        interval: 1000
        onTriggered: root.elapsed += 1
    }

    IpcHandler {
        target: "record"

        function start(mode: string): string {
            return root.start(mode);
        }

        function stop(): void {
            root.stop();
        }

        function togglePause(): void {
            root.togglePause();
        }

        function isRunning(): bool {
            return root.running;
        }
    }
}
