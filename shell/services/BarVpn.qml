pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// nmcli VPN toggle. Reads ~/.config/quantum-moon/vpn.json { enabled, connectionName, displayName }.
Singleton {
    id: root

    readonly property string configPath: `${Paths.config}/vpn.json`

    property var vpnData: ({ enabled: false, connectionName: "", displayName: "" })

    readonly property bool configured: (vpnData?.enabled ?? false) && String(vpnData?.connectionName ?? "").length > 0
    readonly property string connectionName: String(vpnData?.connectionName ?? "")
    readonly property string displayName: {
        const label = String(vpnData?.displayName ?? "");
        return label.length > 0 ? label : connectionName;
    }

    property bool connected: false
    property bool busy: false
    property bool _initialized: false
    property bool _previousConnected: false

    function applyConfig(text: string): void {
        try {
            const parsed = JSON.parse(text);
            root.vpnData = {
                enabled: parsed?.enabled ?? false,
                connectionName: String(parsed?.connectionName ?? ""),
                displayName: String(parsed?.displayName ?? "")
            };
        } catch (e) {
            console.warn("BarVpn: invalid vpn.json:", e);
            root.vpnData = { enabled: false, connectionName: "", displayName: "" };
        }
    }

    function refresh(): void {
        if (!configured)
            return;
        statusProc.running = true;
    }

    function connect(): void {
        if (configured && !busy && !connected)
            toggle();
    }

    function disconnect(): void {
        if (configured && !busy && connected)
            toggle();
    }

    function toggle(): void {
        if (!configured || busy)
            return;
        busy = true;
        toggleProc.wasConnected = connected;
        toggleProc.command = connected ? ["nmcli", "connection", "down", connectionName] : ["nmcli", "connection", "up", connectionName];
        toggleProc.running = true;
    }

    function emitConnectionToast(connectedNow: bool): void {
        if (Config.utilities.toasts.vpnChanged === false)
            return;
        if (connectedNow)
            Toaster.toast("VPN connected", `${displayName} is active`, "shield", "success", 0);
        else
            Toaster.toast("VPN disconnected", `${displayName} is off`, "shield", "info", 0);
    }

    onConnectedChanged: {
        if (!configured)
            return;
        if (!_initialized) {
            _initialized = true;
            _previousConnected = connected;
            return;
        }
        if (connected === _previousConnected)
            return;
        emitConnectionToast(connected);
        _previousConnected = connected;
    }

    onConfiguredChanged: {
        if (configured) {
            refresh();
            return;
        }
        connected = false;
        busy = false;
        _initialized = false;
        _previousConnected = false;
    }

    Component.onCompleted: refresh()

    FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyConfig(text())
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("BarVpn: could not load", root.configPath);
            root.vpnData = { enabled: false, connectionName: "", displayName: "" };
        }
    }

    Process {
        id: statusProc

        command: ["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0);
                root.connected = lines.includes(root.connectionName);
                root.busy = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.busy = false
        }
    }

    Process {
        id: toggleProc

        property bool wasConnected: false

        onExited: exitCode => {
            root.refresh();
            if (exitCode !== 0 && Config.utilities.toasts.vpnChanged !== false) {
                if (!toggleProc.wasConnected)
                    Toaster.toast("VPN connection failed", `Could not connect to ${root.displayName}`, "shield", "error", 0);
                else
                    Toaster.toast("VPN disconnect failed", `Could not disconnect ${root.displayName}`, "shield", "error", 0);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err.length > 0)
                    console.warn("BarVpn:", err);
            }
        }
    }

    Process {
        running: root.configured
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.refresh()
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.configured
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "vpn"

        function toggle(): void {
            root.toggle();
        }

        function connect(): void {
            root.connect();
        }

        function disconnect(): void {
            root.disconnect();
        }

        function isConnected(): bool {
            return root.connected;
        }
    }
}
