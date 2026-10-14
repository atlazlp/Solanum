import QtQuick
import Quickshell.Io
import qs.theme
import qs.components

// CPU and memory arcs sampled locally from /proc/stat and /proc/meminfo every 3 s
// (the lock does not depend on the SystemUsage singleton).
NomaiFrame {
    id: root

    property real cpu: 0
    property real mem: 0
    property real memUsedGib: 0
    property real memTotalGib: 0
    property real _lastIdle: -1
    property real _lastTotal: -1

    padding: Theme.spaceMd
    fill: Theme.alpha(Theme.ink2, 0.9)
    lineOpacity: 0.5
    corners: 4
    implicitHeight: 128

    function parseStat(text: string): void {
        const line = text.split("\n").find(l => l.startsWith("cpu "));
        if (!line)
            return;
        const f = line.trim().split(/\s+/).slice(1).map(Number);
        const idle = f[3] + (f[4] ?? 0);
        const total = f.reduce((a, b) => a + b, 0);
        if (root._lastTotal >= 0 && total > root._lastTotal)
            root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._lastIdle) / (total - root._lastTotal)));
        root._lastIdle = idle;
        root._lastTotal = total;
    }

    function parseMem(text: string): void {
        const get = key => {
            const m = text.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"));
            return m ? Number(m[1]) : 0;
        };
        const total = get("MemTotal");
        const avail = get("MemAvailable");
        if (total > 0) {
            root.mem = Math.max(0, Math.min(1, (total - avail) / total));
            root.memUsedGib = (total - avail) / 1048576;
            root.memTotalGib = total / 1048576;
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        printErrors: false
        onLoaded: root.parseStat(text())
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.parseMem(text())
    }

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spaceSm

        SectionHeader {
            text: "Resources"
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceXl

            Gauge {
                label: "CPU"
                value: root.cpu
                accent: Theme.line
                detail: `${Math.round(root.cpu * 100)}%`
            }

            Gauge {
                label: "MEM"
                value: root.mem
                accent: Theme.spark
                detail: `${root.memUsedGib.toFixed(1)}G`
            }
        }
    }

    component Gauge: Item {
        id: gauge

        property string label: ""
        property real value: 0
        property color accent: Theme.line
        property string detail: ""

        width: 72
        height: 72

        ProgressArc {
            anchors.fill: parent
            value: gauge.value
            accent: gauge.accent
            thickness: 3
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            GlyphText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "body"
                text: gauge.detail
                color: gauge.accent
            }

            GlyphText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "label"
                dim: true
                text: gauge.label
            }
        }
    }
}
