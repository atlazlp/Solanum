import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Connectivity summary + VPN toggle.
Column {
    id: root

    property var host: null
    spacing: Theme.spaceSm
    width: 240

    SectionHeader { text: "Network" }

    Row {
        spacing: Theme.spaceSm

        GlyphIcon {
            icon: Network.icon
            color: Network.connected ? Theme.line : Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            GlyphText {
                text: Network.label
                role: "large"
            }

            GlyphText {
                visible: Network.wifi
                text: `${Network.strength}% signal`
                role: "small"
                dim: true
            }
        }
    }

    SectionHeader {
        visible: BarVpn.configured
        text: "VPN"
    }

    HexButton {
        visible: BarVpn.configured
        width: root.width
        maxWidth: root.width
        icon: "shield"
        iconFill: BarVpn.connected ? 1 : 0
        text: `${BarVpn.displayName}: ${BarVpn.busy ? "..." : (BarVpn.connected ? "connected" : "off")}`
        active: BarVpn.connected
        enabled: !BarVpn.busy
        padding: Theme.spaceXs
        onClicked: BarVpn.toggle()
    }

    HexButton {
        width: root.width
        flat: true
        icon: "settings_ethernet"
        text: "Open nmtui"
        padding: Theme.spaceXs
        onClicked: {
            Quickshell.execDetached(["sh", "-c", "${TERMINAL:-kitty} -e nmtui"]);
            root.host?.hide();
        }
    }
}
