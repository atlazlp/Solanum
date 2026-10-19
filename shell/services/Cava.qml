pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// ASCII cava bars for the desktop visualiser. Ref-counted so the process only runs while needed.
Singleton {
    id: root

    property int bars: Config.get("quantumMoon.background.visualiser.bars", 128)
    property int refs: 0
    // Drop the Pulse connect spike: hold silence for a short warm-up, then ease in.
    property int warmLeft: 0
    property real gate: 0
    property list<real> values: {
        const n = Math.max(1, bars);
        const out = [];
        for (let i = 0; i < n; i++)
            out.push(0);
        return out;
    }

    readonly property bool active: refs > 0 && Config.get("quantumMoon.background.visualiser.enabled", true) !== false

    function acquire(): void {
        refs++;
    }

    function release(): void {
        refs = Math.max(0, refs - 1);
    }

    onActiveChanged: {
        if (active) {
            warmLeft = 45;
            gate = 0;
            const n = Math.max(1, bars);
            const z = [];
            for (let i = 0; i < n; i++)
                z.push(0);
            values = z;
        } else {
            warmLeft = 0;
            gate = 0;
        }
    }

    Process {
        id: proc
        running: root.active
        command: ["sh", "-c", `
cfg=$(mktemp)
cat >"$cfg" <<EOF
[general]
bars = ${root.bars}
framerate = 60
[input]
method = pulse
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
[smoothing]
monstercat = 1
noise_reduction = 77
EOF
exec cava -p "$cfg"
`]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.trim().split(";").filter(s => s.length);
                if (parts.length === 0)
                    return;
                if (root.warmLeft > 0) {
                    root.warmLeft--;
                    root.gate = 0;
                    return;
                }
                root.gate = Math.min(1, root.gate + 0.04);
                const g = root.gate;
                const next = [];
                const n = root.bars;
                for (let i = 0; i < n; i++) {
                    const v = parseInt(parts[i] ?? "0", 10);
                    const raw = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 1000));
                    next.push(raw * g);
                }
                root.values = next;
            }
        }
    }
}
