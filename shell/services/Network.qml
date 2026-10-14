pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.utils

// Connectivity summary from Quickshell.Networking (NetworkManager backend), with an nmcli
// fallback poll when no backend devices show up.
Singleton {
    id: root

    readonly property list<var> devices: Networking.devices.values
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks?.values?.find(n => n.connected) ?? null

    property bool fallback: false
    property bool fbConnected: false
    property bool fbWired: false
    property string fbSsid: ""
    property int fbStrength: 0

    readonly property bool wired: fallback ? fbWired : wiredDevice !== null
    readonly property bool wifi: fallback ? (!fbWired && fbConnected) : (wifiNetwork !== null)
    readonly property bool connected: fallback ? fbConnected : (wired || wifi)
    readonly property string ssid: fallback ? fbSsid : (wifiNetwork?.name ?? "")
    readonly property int strength: {
        if (fallback)
            return fbStrength;
        const s = wifiNetwork?.signalStrength ?? 0;
        return Math.round(s <= 1 ? s * 100 : s);
    }
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string icon: wired ? "lan" : (wifi ? Icons.getNetworkIcon(strength, false) : (wifiEnabled ? "signal_wifi_off" : "wifi_off"))
    readonly property string label: wired ? "Wired" : (wifi ? ssid : "Offline")

    Timer {
        // If the backend produced no devices after 4 s, poll nmcli instead.
        interval: 4000
        running: true
        onTriggered: {
            if (root.devices.length === 0) {
                root.fallback = true;
                nmcliProc.running = true;
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.fallback
        onTriggered: nmcliProc.running = true
    }

    Process {
        id: nmcliProc

        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null; echo ---; nmcli -t -f ACTIVE,SIGNAL,SSID device wifi 2>/dev/null | grep '^yes' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [devs, wifi] = text.split("---");
                let wired = false, conn = false;
                for (const line of (devs ?? "").trim().split("\n")) {
                    const [dev, type, state] = line.split(":");
                    if (state === "connected") {
                        conn = true;
                        if (type === "ethernet")
                            wired = true;
                    }
                }
                const w = (wifi ?? "").trim().split(":");
                root.fbWired = wired;
                root.fbConnected = conn;
                root.fbSsid = w.length >= 3 ? w.slice(2).join(":") : "";
                root.fbStrength = w.length >= 2 ? parseInt(w[1]) || 0 : 0;
            }
        }
    }
}
