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
    property string query: ""
    property var matchMap: ({})
    property bool railHot: false

    readonly property list<var> tabs: [
        { id: "appearance", label: "Appearance", icon: "palette", file: "AppearancePane.qml", blurb: "Type, motion, spacing and the palette" },
        { id: "quantumMoon", label: "Solanum", icon: "public", file: "QuantumMoonPane.qml", blurb: "Planet panel, wallpapers and the live solar system" },
        { id: "bar", label: "Bar", icon: "web_asset", file: "BarPane.qml", blurb: "Segments, status glyphs, tray and workspaces" },
        { id: "screens", label: "Screens", icon: "monitor", file: "ScreensPane.qml", blurb: "Which monitor each part of the shell uses" },
        { id: "launcher", label: "Launcher", icon: "rocket_launch", file: "LauncherPane.qml", blurb: "Prefixes, favourites and hidden entries" },
        { id: "notifications", label: "Notifications", icon: "notifications", file: "NotificationsPane.qml", blurb: "Popups, Signals, the ship log and shell toasts" },
        { id: "dashboard", label: "Dashboard", icon: "dashboard", file: "DashboardPane.qml", blurb: "Meters, media and weather" },
        { id: "idle", label: "Idle & Lock", icon: "lock_clock", file: "IdlePane.qml", blurb: "What happens when you step away, and the lock screen" },
        { id: "audio", label: "Audio", icon: "volume_up", file: "AudioPane.qml", blurb: "Volume, brightness and the on-screen display" },
        { id: "nightlight", label: "Night & Game", icon: "nightlight", file: "NightGamePane.qml", blurb: "Colour temperature and game mode" },
        { id: "session", label: "Session", icon: "power_settings_new", file: "SessionPane.qml", blurb: "Login and the power buttons" },
        { id: "vpn", label: "VPN", icon: "vpn_lock", file: "VpnPane.qml", blurb: "The connection shown in the bar" },
        { id: "services", label: "Services", icon: "dns", file: "ServicesPane.qml", blurb: "Local models and the KVM scripts" }
    ]
    readonly property var currentTab: {
        for (let i = 0; i < tabs.length; i++)
            if (tabs[i].id === current)
                return tabs[i];
        return tabs[0];
    }

    readonly property var shownTabs: {
        void root.matchMap;
        void root.query;
        const out = [];
        for (let i = 0; i < tabs.length; i++) {
            if (tabShown(tabs[i]))
                out.push(tabs[i]);
        }
        return out;
    }

    implicitWidth: 1100
    implicitHeight: 720
    focus: true

    function tabNamed(t): bool {
        const q = query.trim().toLowerCase();
        if (q === "")
            return false;
        return String(t.label).toLowerCase().indexOf(q) >= 0 || String(t.blurb).toLowerCase().indexOf(q) >= 0;
    }

    function rowFilterFor(t): string {
        if (query.trim() === "" || tabNamed(t))
            return "";
        return query;
    }

    function tabShown(t): bool {
        if (query.trim() === "")
            return true;
        if (tabNamed(t))
            return true;
        const n = matchMap[t.id];
        if (n === undefined)
            return true;
        return n > 0;
    }

    function noteMatches(id: string, n: int): void {
        if (matchMap[id] === n)
            return;
        const next = Object.assign({}, matchMap);
        next[id] = n;
        matchMap = next;
    }

    function pickVisible(): void {
        if (query.trim() === "")
            return;
        const vis = shownTabs;
        if (vis.length === 0)
            return;
        for (let i = 0; i < vis.length; i++) {
            if (vis[i].id === current)
                return;
        }
        current = vis[0].id;
    }

    function reveal(): void {
        revealer.trigger();
        Qt.callLater(() => root.forceActiveFocus());
    }

    function close(): void {
        SettingsStore.flushNow();
        Services.Visibilities.close("settings", root.visibilities);
    }

    onQueryChanged: Qt.callLater(pickVisible)
    onMatchMapChanged: Qt.callLater(pickVisible)
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

            Item {
                id: rail
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 210

                Column {
                    id: head
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
                            text: "Solanum"
                            role: "label"
                            dim: true
                        }
                    }

                    NomaiTextField {
                        id: search
                        width: parent.width
                        placeholder: "Search"
                        icon: "search"
                        onTextChanged: root.query = text
                        onEscaped: {
                            if (text !== "") {
                                text = "";
                                root.query = "";
                            } else {
                                root.close();
                            }
                        }
                    }

                    NomaiDivider {
                        width: 60
                    }
                }

                Flickable {
                    id: railScroll
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: head.bottom
                    anchors.topMargin: Theme.spaceMd
                    anchors.bottom: foot.top
                    anchors.bottomMargin: Theme.spaceSm
                    clip: true
                    contentWidth: width
                    contentHeight: nav.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    onMovementStarted: root.railHot = true
                    onMovementEnded: railCool.restart()
                    onContentYChanged: {
                        root.railHot = true;
                        railCool.restart();
                    }

                    NomaiTabs {
                        id: nav
                        width: railScroll.width
                        model: root.shownTabs
                        current: root.current
                        onSelected: id => root.current = id
                    }

                    Rectangle {
                        visible: railScroll.contentHeight > railScroll.height
                        opacity: root.railHot || railHover.hovered ? 1 : 0
                        anchors.right: parent.right
                        width: 2
                        y: railScroll.height * railScroll.visibleArea.yPosition
                        height: Math.max(16, railScroll.height * railScroll.visibleArea.heightRatio)
                        color: Theme.alpha(Theme.line, 0.6)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Motion.fast
                                easing.type: Motion.fade
                            }
                        }

                        HoverHandler {
                            id: railHover
                        }
                    }

                    Timer {
                        id: railCool
                        interval: 700
                        onTriggered: root.railHot = false
                    }
                }

                Column {
                    id: foot
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

                Item {
                    id: paneHost
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.topMargin: Theme.spaceMd
                    anchors.bottom: parent.bottom

                    Repeater {
                        model: root.tabs

                        Item {
                            id: paneSlot
                            required property var modelData
                            anchors.fill: parent
                            visible: modelData.id === root.current

                            Loader {
                                id: paneLoader
                                anchors.fill: parent
                                active: root.query !== "" || paneSlot.modelData.id === root.current
                                source: "panes/" + paneSlot.modelData.file

                                onLoaded: {
                                    item.filter = Qt.binding(() => root.rowFilterFor(paneSlot.modelData));
                                    root.noteMatches(paneSlot.modelData.id, item.matches);
                                }
                            }

                            Connections {
                                target: paneLoader.item
                                ignoreUnknownSignals: true
                                function onMatchesChanged(): void {
                                    if (paneLoader.item)
                                        root.noteMatches(paneSlot.modelData.id, paneLoader.item.matches);
                                }
                            }
                        }
                    }

                    GlyphText {
                        visible: root.query.trim() !== "" && root.shownTabs.length === 0
                        anchors.centerIn: parent
                        text: "No matching settings"
                        role: "small"
                        dim: true
                    }
                }
            }
        }
    }
}
