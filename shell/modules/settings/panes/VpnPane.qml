import QtQuick
import Quickshell.Io
import qs.config
import qs.theme
import qs.components
import qs.services as Services
import qs.modules.settings

SettingsPane {
    id: pane

    property list<var> connections: []

    readonly property var connectionModel: {
        void vpn.generation;
        const cur = String(vpn.get("connectionName", "") ?? "");
        const list = connections.slice();
        if (cur !== "" && !list.some(c => c.value === cur))
            list.unshift({ value: cur, label: cur + " (not found)" });
        return list;
    }

    JsonStore {
        id: vpn
        path: `${Paths.config}/vpn.json`
    }

    Process {
        id: nmcli
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const i = line.lastIndexOf(":");
                    if (i < 0)
                        continue;
                    const name = line.slice(0, i).replace(/\\:/g, ":");
                    const type = line.slice(i + 1).toLowerCase();
                    if (type.includes("vpn") || type.includes("wireguard"))
                        out.push({ value: name, label: `${name}  (${type})` });
                }
                pane.connections = out;
            }
        }
    }

    SettingRow {
        label: "Status"
        description: vpn.loaded ? "~/.config/quantum-moon/vpn.json" : "vpn.json will be created on the first change"

        GlyphText {
            text: Services.BarVpn.configured ? (Services.BarVpn.connected ? "connected" : "disconnected") : "not configured"
            role: "label"
            color: Services.BarVpn.connected ? Theme.success : Theme.textDim
        }
    }

    SwitchRow {
        store: vpn
        key: "enabled"
        label: "Enabled"
        description: "Show the VPN glyph in the bar and allow the toggle"
    }

    ComboRow {
        store: vpn
        key: "connectionName"
        label: "Connection"
        description: nmcli.running ? "listing nmcli connections..." : (pane.connections.length === 0 ? "no vpn / wireguard connections found" : "nmcli vpn and wireguard connections")
        placeholder: "nmcli connection"
        model: pane.connectionModel
        comboWidth: 280
    }

    TextRow {
        store: vpn
        key: "displayName"
        label: "Display name"
        description: "Label used in popouts and toasts (defaults to the connection name)"
        placeholder: "e.g. Office"
    }

    SettingRow {
        label: "Refresh connections"
        separator: false

        HexButton {
            icon: "refresh"
            text: "nmcli"
            enabled: !nmcli.running
            onClicked: nmcli.running = true
        }
    }
}
