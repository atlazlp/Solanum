pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU / GPU / memory / storage sampling. Bump `refCount` while a consumer is on screen; the
// sampler runs every Config.dashboard.resourceUpdateInterval ms only while refCount > 0.
Singleton {
    id: root

    property int refCount: 0
    readonly property int historyLength: Config.get("dashboard.historyLength", 30)

    // CPU
    property string cpuName: ""
    property real cpuPerc: 0
    property real cpuTemp: 0
    property list<real> cpuHistory: []

    // GPU
    property string gpuType: "NONE"      // GENERIC (sysfs busy percent) | NVIDIA | NONE
    property string gpuName: ""
    property real gpuPerc: 0
    property real gpuTemp: 0
    property list<real> gpuHistory: []

    // Memory (KiB)
    property real memUsed: 0
    property real memTotal: 0
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0
    property list<real> memHistory: []

    // Storage: [{ mount, used, total, free, perc, hasRoot }] in KiB
    property var disks: []
    readonly property real storagePerc: {
        let used = 0, total = 0;
        for (const d of disks) {
            used += d.used;
            total += d.total;
        }
        return total > 0 ? used / total : 0;
    }
    readonly property real storageUsed: disks.reduce((a, d) => a + d.used, 0)
    readonly property real storageTotal: disks.reduce((a, d) => a + d.total, 0)

    property real lastCpuIdle: 0
    property real lastCpuTotal: 0

    function push(list, v): list<real> {
        const out = list.slice(-(historyLength - 1));
        out.push(v);
        return out;
    }

    function cleanCpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|CPU|\d+(?:th|nd|rd|st) Gen |Core |Processor/gi, "").replace(/\s+/g, " ").trim();
    }

    function cleanGpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|Graphics/gi, "").replace(/\s+/g, " ").trim();
    }

    // KiB -> { value, unit }
    function formatKib(kib: real): var {
        const mib = 1024, gib = 1024 ** 2, tib = 1024 ** 3;
        if (kib >= tib)
            return { value: kib / tib, unit: "TiB" };
        if (kib >= gib)
            return { value: kib / gib, unit: "GiB" };
        if (kib >= mib)
            return { value: kib / mib, unit: "MiB" };
        return { value: kib, unit: "KiB" };
    }

    function formatKibStr(kib: real, decimals: int): string {
        const f = formatKib(kib);
        return `${f.value.toFixed(decimals ?? 1)} ${f.unit}`;
    }

    Timer {
        running: root.refCount > 0
        interval: Config.get("dashboard.resourceUpdateInterval", 3000)
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            storage.running = true;
            if (root.gpuType !== "NONE")
                gpuUsage.running = true;
            sensors.running = true;
        }
    }

    FileView {
        path: "/proc/cpuinfo"
        onLoaded: {
            const m = text().match(/model name\s*:\s*(.+)/);
            if (m)
                root.cpuName = root.cleanCpuName(m[1]);
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const data = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (!data)
                return;
            const stats = data.slice(1).map(n => parseInt(n, 10));
            const total = stats.reduce((a, b) => a + b, 0);
            const idle = stats[3] + (stats[4] ?? 0);
            const totalDiff = total - root.lastCpuTotal;
            const idleDiff = idle - root.lastCpuIdle;
            const perc = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;
            root.lastCpuTotal = total;
            root.lastCpuIdle = idle;
            if (totalDiff <= 0)
                return;
            root.cpuPerc = perc;
            root.cpuHistory = root.push(root.cpuHistory, perc);
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const data = text();
            const total = parseInt(data.match(/MemTotal: *(\d+)/)?.[1] ?? "0", 10) || 1;
            const avail = parseInt(data.match(/MemAvailable: *(\d+)/)?.[1] ?? "0", 10) || 0;
            root.memTotal = total;
            root.memUsed = total - avail;
            root.memHistory = root.push(root.memHistory, root.memPerc);
        }
    }

    Process {
        id: storage

        command: ["lsblk", "-J", "-b", "-o", "NAME,SIZE,TYPE,FSUSED,FSSIZE,MOUNTPOINT"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const list = [];
                const seen = new Set();
                const aggregate = dev => {
                    let used = 0, size = 0;
                    let isRoot = dev.mountpoint === "/" || (dev.mountpoints && dev.mountpoints.includes("/"));
                    if (!seen.has(dev.name)) {
                        used = parseInt(dev.fsused) || 0;
                        size = parseInt(dev.fssize) || 0;
                        seen.add(dev.name);
                    }
                    for (const child of dev.children ?? []) {
                        const s = aggregate(child);
                        used += s.used;
                        size += s.size;
                        if (s.isRoot)
                            isRoot = true;
                    }
                    return { used, size, isRoot };
                };
                for (const dev of data.blockdevices ?? []) {
                    if (dev.type !== "disk" || dev.name.startsWith("zram"))
                        continue;
                    const s = aggregate(dev);
                    if (s.size === 0)
                        continue;
                    list.push({
                        mount: dev.name,
                        used: s.used / 1024,
                        total: s.size / 1024,
                        free: (s.size - s.used) / 1024,
                        perc: s.size > 0 ? s.used / s.size : 0,
                        hasRoot: s.isRoot
                    });
                }
                root.disks = list.sort((a, b) => {
                    if (a.hasRoot && !b.hasRoot)
                        return -1;
                    if (!a.hasRoot && b.hasRoot)
                        return 1;
                    return a.mount.localeCompare(b.mount);
                });
            }
        }
    }

    // One-time GPU name + type detection.
    Process {
        running: true
        command: ["sh", "-c", "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || glxinfo -B 2>/dev/null | grep 'Device:' | cut -d':' -f2 | cut -d'(' -f1 || lspci 2>/dev/null | grep -i 'vga\\|3d controller\\|display' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (!out)
                    return;
                const low = out.toLowerCase();
                if (low.includes("nvidia") || low.includes("geforce") || low.includes("rtx") || low.includes("gtx") || low.includes("rx")) {
                    root.gpuName = root.cleanGpuName(out);
                } else {
                    const bracket = out.match(/\[([^\]]+)\][^\[]*$/);
                    if (bracket)
                        root.gpuName = root.cleanGpuName(bracket[1]);
                    else {
                        const colon = out.match(/:\s*(.+)/);
                        if (colon)
                            root.gpuName = root.cleanGpuName(colon[1]);
                    }
                }
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.gpuType = text.trim() || "NONE"
        }
    }

    Process {
        id: gpuUsage

        command: root.gpuType === "GENERIC" ? ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent"] : root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"] : ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let perc = 0;
                if (root.gpuType === "GENERIC") {
                    // Several cards (dGPU + iGPU): report the busiest one.
                    const percs = text.trim().split("\n").map(s => parseInt(s, 10)).filter(n => !isNaN(n));
                    perc = percs.length ? Math.max(...percs) / 100 : 0;
                } else if (root.gpuType === "NVIDIA") {
                    const [usage, temp] = text.trim().split(",");
                    perc = (parseInt(usage, 10) || 0) / 100;
                    root.gpuTemp = parseInt(temp, 10) || 0;
                }
                root.gpuPerc = perc;
                root.gpuHistory = root.push(root.gpuHistory, perc);
            }
        }
    }

    Process {
        id: sensors

        command: ["sensors"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                let cpuTemp = text.match(/(?:Package id [0-9]+|Tdie):\s+((\+|-)[0-9.]+)(°| )C/);
                if (!cpuTemp)
                    cpuTemp = text.match(/Tctl:\s+((\+|-)[0-9.]+)(°| )C/);
                if (cpuTemp)
                    root.cpuTemp = parseFloat(cpuTemp[1]);

                if (root.gpuType !== "GENERIC")
                    return;
                let eligible = false;
                let best = 0;
                for (const line of text.trim().split("\n")) {
                    if (line === "Adapter: PCI adapter")
                        eligible = true;
                    else if (line === "")
                        eligible = false;
                    else if (eligible) {
                        let m = line.match(/^(temp[0-9]+|GPU core|edge)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);
                        if (!m)
                            m = line.match(/^(junction|mem)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);
                        if (m)
                            best = Math.max(best, parseFloat(m[2]));
                    }
                }
                root.gpuTemp = best;
            }
        }
    }
}
