pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services as Services
import qs.modules.settings

// Settings window (centre slot, 1100 x 720). Left: hex nav rail; right: the selected pane.
// Every pane row writes through SettingsStore (debounced Config.save) or a JsonStore for the
// side files (vpn.json, services.json). Esc closes.
Item {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    property string current: "appearance"

    readonly property list<var> tabs: [
        { id: "appearance", label: "Appearance", icon: "palette", file: "AppearancePane.qml", blurb: "Scale, motion and the active palette" },
        { id: "bar", label: "Bar", icon: "web_asset", file: "BarPane.qml", blurb: "Segments, status glyphs, tray and workspaces" },
        { id: "screens", label: "Screens", icon: "monitor", file: "ScreensPane.qml", blurb: "Monitor roles and the module matrix" },
        { id: "launcher", label: "Launcher", icon: "rocket_launch", file: "LauncherPane.qml", blurb: "Prefixes, favourites and hidden entries" },
        { id: "notifications", label: "Notifications", icon: "notifications", file: "NotificationsPane.qml", blurb: "Popups and the ship log history" },
        { id: "dashboard", label: "Dashboard", icon: "dashboard", file: "DashboardPane.qml", blurb: "Dashboard, weather and the OSD" },
        { id: "idle", label: "Idle & Lock", icon: "lock_clock", file: "IdlePane.qml", blurb: "Idle timeouts and the lock screen" },
        { id: "quantumMoon", label: "Quantum Moon", icon: "public", file: "QuantumMoonPane.qml", blurb: "Planet panel, background and engine root" },
        { id: "audio", label: "Audio", icon: "volume_up", file: "AudioPane.qml", blurb: "Volume and brightness steps" },
        { id: "nightlight", label: "Night & Game", icon: "nightlight", file: "NightGamePane.qml", blurb: "Night light temperature and game mode" },
        { id: "session", label: "Session", icon: "power_settings_new", file: "SessionPane.qml", blurb: "Commands behind the session buttons" },
        { id: "vpn", label: "VPN", icon: "vpn_lock", file: "VpnPane.qml", blurb: "nmcli connection shown in the bar (vpn.json)" },
        { id: "services", label: "Services", icon: "dns", file: "ServicesPane.qml", blurb: "LLM and KVM integration paths (services.json)" }
    ]
    readonly property var currentTab: tabs.find(t => t.id === current) ?? tabs[0]

    implicitWidth: 1100
    implicitHeight: 720
    focus: true

    function reveal(): void {
        revealer.trigger();
        Qt.callLater(() => root.forceActiveFocus());
    }

    function close(): void {
        SettingsStore.flushNow();
        Services.Visibilities.close("settings", root.visibilities);
    }

    Keys.onEscapePressed: close()
    Component.onDestruction: SettingsStore.flushNow()

    NomaiFrame {
        anchors.fill: parent
        chamfer: Theme.chamferLg
        fill: Theme.ink1
        glow: true
        ticks: true
        padding: Theme.spaceLg

        GlyphReveal {
            id: revealer
            anchors.fill: parent
            autoTrigger: false

            // ---- rail ----
            Item {
                id: rail
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 210

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Theme.spaceMd

                    Column {
                        spacing: 2

                        GlyphText {
                            text: "Settings"
                            role: "title"
                        }

                        GlyphText {
                            text: "quantum-moon shell"
                            role: "label"
                            dim: true
                        }
                    }

                    NomaiDivider {
                        width: 60
                    }

                    NomaiTabs {
                        id: nav
                        width: parent.width
                        model: root.tabs
                        current: root.current
                        onSelected: id => root.current = id
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    spacing: 2

                    GlyphText {
                        text: Paths.shellConfig.replace(Paths.home, "~")
                        role: "mono"
                        dim: true
                        width: rail.width
                        font.pointSize: Theme.sizeLabel
                    }

                    GlyphText {
                        text: SettingsStore.generation >= 0 && Object.keys(SettingsStore.pending).length > 0 ? "writing..." : "saved"
                        role: "label"
                        dim: true
                    }
                }
            }

            Rectangle {
                id: split
                anchors.left: rail.right
                anchors.leftMargin: Theme.spaceLg
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.alpha(Theme.lineDim, 0.6)
            }

            // ---- pane ----
            Item {
                anchors.left: split.right
                anchors.leftMargin: Theme.spaceLg
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Column {
                    id: header
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Theme.spaceXs

                    SectionHeader {
                        text: root.currentTab.label
                    }

                    GlyphText {
                        text: root.currentTab.blurb
                        role: "small"
                        dim: true
                    }
                }

                Loader {
                    id: paneLoader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.topMargin: Theme.spaceMd
                    anchors.bottom: parent.bottom
                    source: "panes/" + root.currentTab.file
                    opacity: status === Loader.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Motion.normal; easing.type: Motion.enter }
                    }

                    onStatusChanged: {
                        if (status === Loader.Error)
                            console.warn("Settings: failed to load pane", source);
                    }
                }
            }
        }
    }
}
