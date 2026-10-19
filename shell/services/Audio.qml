pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Pipewire default sink/source, volume/mute, stream list, analog port switching (pactl),
// mic reload script and a ref-counted peak monitor on the default sink.
Singleton {
    id: root

    property string previousSinkName: ""
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []

    readonly property string analogSinkId: Config.audio.analogSinkId ?? ""
    readonly property string analogPortSpeakers: "analog-output-lineout"
    readonly property string analogPortHeadphones: "analog-output-headphones"
    property string analogSinkName: ""
    readonly property bool analogPortsAvailable: analogSinkName.length > 0
    property string analogActivePort: ""   // "speakers" | "headphones" | ""

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property real increment: Config.audio.increment ?? 0.1
    readonly property real maxVolume: Config.audio.maxVolume ?? 1

    // Peak meter: bump peakRefs while a visualiser is on screen.
    property int peakRefs: 0
    readonly property real peak: peakMonitor.peak

    readonly property string reloadMicScript: `${Paths.scripts}/qm-audio-reload-mic.sh`

    function clampVolume(v: real): real {
        return Math.max(0, Math.min(maxVolume, v));
    }

    function setVolume(v: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = clampVolume(v);
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || increment));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || increment));
    }

    function toggleMute(): void {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setSourceVolume(v: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = clampVolume(v);
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || increment));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || increment));
    }

    function toggleSourceMute(): void {
        if (source?.ready && source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function setAudioSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setAudioSource(node: PwNode): void {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function cycleNextAudioOutput(): void {
        if (sinks.length === 0)
            return;
        const i = sinks.findIndex(s => s === sink);
        setAudioSink(sinks[(i + 1) % sinks.length]);
    }

    function analogSinkNode(): PwNode {
        if (!analogSinkId)
            return null;
        return sinks.find(n => n.name && n.name.includes(analogSinkId)) ?? null;
    }

    function updateAnalogSinkName(): void {
        const node = analogSinkNode();
        const name = node?.name ?? "";
        if (analogSinkName !== name) {
            analogSinkName = name;
            refreshAnalogPort();
        }
    }

    function refreshAnalogPort(): void {
        if (analogPortsAvailable)
            refreshPortProc.running = true;
    }

    function setAnalogPort(portId: string): void {
        if (!analogPortsAvailable)
            return;
        const node = analogSinkNode();
        if (node)
            setAudioSink(node);
        setPortProc.command = ["pactl", "set-sink-port", analogSinkName, portId];
        setPortProc.running = true;
    }

    function setAnalogSpeakers(): void {
        setAnalogPort(analogPortSpeakers);
    }

    function setAnalogHeadphones(): void {
        setAnalogPort(analogPortHeadphones);
    }

    function reloadMicrophone(): void {
        reloadMicProc.running = true;
    }

    function setStreamVolume(stream: PwNode, v: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = clampVolume(v);
        }
    }

    function setStreamMuted(stream: PwNode, m: bool): void {
        if (stream?.ready && stream?.audio)
            stream.audio.muted = m;
    }

    function streamName(stream: PwNode): string {
        if (!stream)
            return "Unknown";
        return stream.properties["application.name"] || stream.description || stream.name || "Unknown Application";
    }

    function streamMediaHint(stream: PwNode): string {
        if (!stream)
            return "";
        const p = stream.properties ?? {};
        return p["media.name"] || p["media.title"] || p["window.title"] || "";
    }

    // Hide PipeWire internals and cava (desktop visualiser) from mixer UIs.
    function isMixerStream(stream: PwNode): bool {
        if (!stream)
            return false;
        const p = stream.properties ?? {};
        const nodeName = String(p["node.name"] ?? stream.name ?? "");
        const app = String(p["application.name"] ?? "");
        const binary = String(p["application.process.binary"] ?? "");
        const media = String(p["media.name"] ?? "");
        const blob = `${nodeName} ${app} ${binary} ${media} ${stream.description ?? ""}`.toLowerCase();
        if (nodeName.startsWith("echo-cancel"))
            return false;
        if (media === "Peak detect" || app === "Quickshell")
            return false;
        if (app.toLowerCase() === "cava" || binary.toLowerCase() === "cava" || blob.includes("cava"))
            return false;
        return true;
    }

    function mixerStreams(): list<PwNode> {
        return streams.filter(s => isMixerStream(s));
    }

    // Hover label: app name, plus media title when the same app has multiple streams.
    function streamTooltip(stream: PwNode, allStreams: list<PwNode>): string {
        const app = streamName(stream);
        const media = streamMediaHint(stream).trim();
        if (!media || media === app)
            return app;
        const list = allStreams ?? mixerStreams();
        let count = 0;
        for (let i = 0; i < list.length; i++) {
            if (streamName(list[i]) === app)
                count++;
        }
        if (count > 1)
            return `${app}\n${media}`;
        return app;
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;
        refreshAnalogPort();
        const name = sink.description || sink.name || "Unknown Device";
        if (previousSinkName && previousSinkName !== name && Config.utilities.toasts.audioOutputChanged)
            Toaster.toast("Audio output changed", `Now using: ${name}`, "volume_up");
        previousSinkName = name;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;
        const name = source.description || source.name || "Unknown Device";
        if (previousSourceName && previousSourceName !== name && Config.utilities.toasts.audioInputChanged)
            Toaster.toast("Audio input changed", `Now using: ${name}`, "mic");
        previousSourceName = name;
    }

    Component.onCompleted: {
        previousSinkName = sink?.description || sink?.name || "";
        previousSourceName = source?.description || source?.name || "";
        updateAnalogSinkName();
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            const newSinks = [], newSources = [], newStreams = [];
            for (const node of Pipewire.nodes.values) {
                if (!node.isStream) {
                    if (node.isSink)
                        newSinks.push(node);
                    else if (node.audio)
                        newSources.push(node);
                } else if (node.audio) {
                    newStreams.push(node);
                }
            }
            root.sinks = newSinks;
            root.sources = newSources;
            root.streams = newStreams;
            root.updateAnalogSinkName();
        }
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    PwNodePeakMonitor {
        id: peakMonitor
        node: root.sink
        enabled: root.peakRefs > 0 && !GameMode.enabled
    }

    Timer {
        interval: 3000
        running: root.analogPortsAvailable
        repeat: true
        onTriggered: root.refreshAnalogPort()
    }

    Process {
        id: refreshPortProc

        command: ["sh", "-c", `pactl list sinks 2>/dev/null | awk -v sink="${root.analogSinkName}" '$1=="Name:" && $2==sink { show=1 } show && $1=="Active" && $2=="Port:" { print $3; exit }'`]
        stdout: StdioCollector {
            onStreamFinished: {
                const port = text.trim();
                if (port === root.analogPortSpeakers)
                    root.analogActivePort = "speakers";
                else if (port === root.analogPortHeadphones)
                    root.analogActivePort = "headphones";
                else
                    root.analogActivePort = "";
            }
        }
    }

    Process {
        id: setPortProc
        onExited: refreshPortProc.running = true
    }

    Process {
        id: reloadMicProc

        command: ["sh", "-c", `if [ -x "$1" ]; then exec "$1"; else echo "missing $1" >&2; exit 127; fi`, "qm-reload-mic", root.reloadMicScript]
        onExited: exitCode => {
            if (exitCode === 0)
                Toaster.toast("Microphone reloaded", "PipeWire capture was restarted", "mic", "success", 0);
            else if (exitCode === 127)
                Toaster.toast("Microphone reload unavailable", `${root.reloadMicScript} not found`, "mic_off", "warn", 0);
            else
                Toaster.toast("Microphone reload failed", "Could not restart WirePlumber", "mic_off", "error", 0);
        }
    }

    IpcHandler {
        target: "audio"

        function volumeUp(): void {
            root.incrementVolume(0);
        }

        function volumeDown(): void {
            root.decrementVolume(0);
        }

        function muteToggle(): void {
            root.toggleMute();
        }

        function micMuteToggle(): void {
            root.toggleSourceMute();
        }

        function cycleOutput(): void {
            root.cycleNextAudioOutput();
        }

        function analogSpeakers(): void {
            root.setAnalogSpeakers();
        }

        function analogHeadphones(): void {
            root.setAnalogHeadphones();
        }

        function reloadMic(): void {
            root.reloadMicrophone();
        }

        // 0.5 | 50% | +0.1 | -0.1 | +10% | 10%-
        function setVolume(value: string): string {
            let v = root.volume;
            const s = value.trim();
            const pct = s.includes("%");
            const num = parseFloat(s.replace(/[%+\-]/g, ""));
            if (isNaN(num))
                return `Invalid value: ${value}`;
            const delta = pct ? num / 100 : num;
            if (s.startsWith("+"))
                v += delta;
            else if (s.startsWith("-") || s.endsWith("-"))
                v -= delta;
            else
                v = delta;
            root.setVolume(v);
            return `volume ${Math.round(root.clampVolume(v) * 100)}%`;
        }

        function getVolume(): real {
            return root.volume;
        }

        function isMuted(): bool {
            return root.muted;
        }
    }
}
