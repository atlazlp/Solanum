pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// brightnessctl for the internal panel, ddcutil (debounced 500 ms) for DDC monitors. One Monitor per screen.
Singleton {
    id: root

    property list<var> ddcMonitors: []
    readonly property var ddcMonitorMap: {
        const map = {};
        for (const m of ddcMonitors)
            map[m.connector] = m;
        return map;
    }
    readonly property list<Monitor> monitors: variants.instances
    readonly property real increment: Config.brightness.increment ?? 0.1

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.modelData === screen) ?? null;
    }

    function getMonitor(query: string): var {
        if (query === "active")
            return monitors.find(m => Hypr.monitorFor(m.modelData)?.focused) ?? monitors[0] ?? null;
        if (query.startsWith("model:"))
            return monitors.find(m => m.modelData.model === query.slice(6)) ?? null;
        if (query.startsWith("serial:"))
            return monitors.find(m => m.modelData.serialNumber === query.slice(7)) ?? null;
        if (query.startsWith("id:")) {
            const id = parseInt(query.slice(3), 10);
            return monitors.find(m => Hypr.monitorFor(m.modelData)?.id === id) ?? null;
        }
        return monitors.find(m => m.modelData.name === query) ?? null;
    }

    function increaseBrightness(): void {
        const m = getMonitor("active");
        if (m)
            m.setBrightness(m.brightness + increment);
    }

    function decreaseBrightness(): void {
        const m = getMonitor("active");
        if (m)
            m.setBrightness(m.brightness - increment);
    }

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    Variants {
        id: variants
        model: Quickshell.screens

        Monitor {}
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const d of text.trim().split("\n\n")) {
                    if (!d.startsWith("Display "))
                        continue;
                    const bus = d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/);
                    const conn = d.match(/DRM connector:\s+(.*)/);
                    if (bus && conn)
                        out.push({ busNum: bus[1], connector: conn[1].trim().replace(/^card\d+-/, "") });
                }
                root.ddcMonitors = out;
            }
        }
    }

    IpcHandler {
        target: "brightness"

        function get(): real {
            return getFor("active");
        }

        function getFor(query: string): real {
            return root.getMonitor(query)?.brightness ?? -1;
        }

        function set(value: string): string {
            return setFor("active", value);
        }

        // 0.1 | +0.1 | 0.1- | 10% | +10% | 10%-
        function setFor(query: string, value: string): string {
            const monitor = root.getMonitor(query);
            if (!monitor)
                return "Invalid monitor: " + query;

            let target;
            if (value.endsWith("%-"))
                target = monitor.brightness - parseFloat(value.slice(0, -2)) / 100;
            else if (value.startsWith("+") && value.endsWith("%"))
                target = monitor.brightness + parseFloat(value.slice(1, -1)) / 100;
            else if (value.endsWith("%"))
                target = parseFloat(value.slice(0, -1)) / 100;
            else if (value.startsWith("+"))
                target = monitor.brightness + parseFloat(value.slice(1));
            else if (value.endsWith("-"))
                target = monitor.brightness - parseFloat(value.slice(0, -1));
            else if (value.includes("%") || value.includes("-") || value.includes("+"))
                return `Invalid brightness format: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;
            else
                target = parseFloat(value);

            if (isNaN(target))
                return `Failed to parse value: ${value}`;
            monitor.setBrightness(target);
            return `Set monitor ${monitor.modelData.name} brightness to ${+monitor.brightness.toFixed(2)}`;
        }
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property var ddcInfo: root.ddcMonitorMap[modelData.name] ?? null
        readonly property bool isDdc: ddcInfo !== null
        readonly property string busNum: ddcInfo?.busNum ?? ""
        property real brightness: 0
        property real queuedBrightness: NaN

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const parts = text.trim().split(/\s+/);
                    if (parts.length >= 5) {
                        const cur = parseInt(parts[3]), max = parseInt(parts[4]);
                        if (!isNaN(cur) && !isNaN(max) && max > 0)
                            monitor.brightness = cur / max;
                    }
                }
            }
        }

        readonly property Timer timer: Timer {
            interval: 500
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.setBrightness(monitor.queuedBrightness);
                    monitor.queuedBrightness = NaN;
                }
            }
        }

        function setBrightness(value: real): void {
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;
            if (isDdc && timer.running) {
                queuedBrightness = value;
                return;
            }
            brightness = value;
            if (isDdc)
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", String(rounded)]);
            else
                Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`]);
            if (isDdc)
                timer.restart();
        }

        function initBrightness(): void {
            if (isDdc)
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
            else
                initProc.command = ["sh", "-c", "echo a b c $(brightnessctl g 2>/dev/null || echo 0) $(brightnessctl m 2>/dev/null || echo 0)"];
            initProc.running = true;
        }

        onBusNumChanged: initBrightness()
        Component.onCompleted: initBrightness()
    }
}
