pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Aggregate /proc/net/dev throughput (all interfaces except lo). Bump `refCount` while shown.
Singleton {
    id: root

    property int refCount: 0
    readonly property int historyLength: Config.get("dashboard.historyLength", 30)

    // bytes per second
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    // bytes since the shell started sampling
    property real downloadTotal: 0
    property real uploadTotal: 0
    property list<real> downloadHistory: []
    property list<real> uploadHistory: []

    property real prevRx: 0
    property real prevTx: 0
    property real prevTs: 0
    property real initialRx: 0
    property real initialTx: 0
    property bool initialized: false

    function push(list, v): list<real> {
        const out = list.slice(-(historyLength - 1));
        out.push(v);
        return out;
    }

    // bytes/s -> { value, unit }
    function formatRate(bytes: real): var {
        if (!(bytes >= 0) || !isFinite(bytes))
            return { value: 0, unit: "B/s" };
        if (bytes < 1024)
            return { value: bytes, unit: "B/s" };
        if (bytes < 1024 ** 2)
            return { value: bytes / 1024, unit: "KB/s" };
        if (bytes < 1024 ** 3)
            return { value: bytes / 1024 ** 2, unit: "MB/s" };
        return { value: bytes / 1024 ** 3, unit: "GB/s" };
    }

    function formatRateStr(bytes: real): string {
        const f = formatRate(bytes);
        return `${f.value.toFixed(f.unit === "B/s" ? 0 : 1)} ${f.unit}`;
    }

    function formatTotalStr(bytes: real): string {
        if (!(bytes >= 0) || !isFinite(bytes))
            return "0 B";
        if (bytes < 1024)
            return `${bytes.toFixed(0)} B`;
        if (bytes < 1024 ** 2)
            return `${(bytes / 1024).toFixed(1)} KB`;
        if (bytes < 1024 ** 3)
            return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
        return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
    }

    function parseNetDev(content: string): var {
        let rx = 0, tx = 0;
        const lines = content.split("\n");
        for (let i = 2; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line)
                continue;
            const parts = line.split(/\s+/);
            if (parts.length < 10)
                continue;
            if (parts[0].replace(":", "") === "lo")
                continue;
            rx += parseFloat(parts[1]) || 0;
            tx += parseFloat(parts[9]) || 0;
        }
        return { rx, tx };
    }

    FileView {
        id: netDev

        path: "/proc/net/dev"
        onLoaded: {
            const data = root.parseNetDev(text());
            const now = Date.now();
            if (!root.initialized) {
                root.initialRx = root.prevRx = data.rx;
                root.initialTx = root.prevTx = data.tx;
                root.prevTs = now;
                root.initialized = true;
                return;
            }
            const dt = (now - root.prevTs) / 1000;
            if (dt > 0) {
                let rxd = data.rx - root.prevRx;
                let txd = data.tx - root.prevTx;
                if (rxd < 0)
                    rxd += 2 ** 64;
                if (txd < 0)
                    txd += 2 ** 64;
                root.downloadSpeed = rxd / dt;
                root.uploadSpeed = txd / dt;
                root.downloadHistory = root.push(root.downloadHistory, root.downloadSpeed);
                root.uploadHistory = root.push(root.uploadHistory, root.uploadSpeed);
            }
            let down = data.rx - root.initialRx;
            let up = data.tx - root.initialTx;
            if (down < 0)
                down += 2 ** 64;
            if (up < 0)
                up += 2 ** 64;
            root.downloadTotal = down;
            root.uploadTotal = up;
            root.prevRx = data.rx;
            root.prevTx = data.tx;
            root.prevTs = now;
        }
    }

    Timer {
        running: root.refCount > 0
        interval: Config.get("dashboard.resourceUpdateInterval", 3000)
        repeat: true
        triggeredOnStart: true
        onTriggered: netDev.reload()
    }
}
