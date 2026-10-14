pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services as Services

// Ship-log panel (centre slot, 1100 x 720): the notification history as a star map. Left: the
// pannable graph (ShipLogCanvas); right: detail pane; top: search + filter chips.
// Keys: arrows move, Enter opens, Backspace back to groups, / search, p pin, Delete delete, Esc close.
Item {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    property string selectedGroup: ""
    property string selectedEntry: ""
    property string focusedGroup: ""
    property string focusedEntry: ""

    property string appFilter: ""
    property bool filterCritical: false
    property bool filterUnread: false
    property bool filterRumors: false
    readonly property string query: search.text.trim()
    readonly property bool filtering: query !== "" || appFilter !== "" || filterCritical || filterUnread || filterRumors

    readonly property list<var> groups: Services.ShipLog.groups
    readonly property var selectedGroupObj: groups.find(g => g.app === selectedGroup) ?? null
    readonly property var selectedEntryObj: {
        void Services.ShipLog.generation;
        return selectedEntry ? Services.ShipLog.byId(selectedEntry) : null;
    }

    readonly property var entryMatches: {
        const q = query, app = appFilter, crit = filterCritical, unread = filterUnread, rumors = filterRumors;
        if (q === "" && app === "" && !crit && !unread && !rumors)
            return null;
        return e => {
            if (app !== "" && (e.app || "Unknown") !== app)
                return false;
            if (crit && e.urgency !== 2)
                return false;
            if (unread && e.read)
                return false;
            if (rumors && !e.rumor)
                return false;
            return Services.ShipLog.matches(e, q);
        };
    }

    implicitWidth: 1100
    implicitHeight: 720
    focus: true

    function reveal(): void {
        revealer.trigger();
        const pending = Services.ShipLog.pendingQuery;
        if (pending) {
            search.text = pending;
            Services.ShipLog.pendingQuery = "";
        }
        Qt.callLater(() => root.forceActiveFocus());
        Qt.callLater(() => {
            if (Services.ShipLog.pendingReveal) {
                openEntry(Services.ShipLog.pendingReveal);
                Services.ShipLog.pendingReveal = "";
                Services.ShipLog.pendingSelect = "";
            } else if (Services.ShipLog.pendingSelect) {
                selectGroup(Services.ShipLog.pendingSelect);
                Services.ShipLog.pendingSelect = "";
            }
        });
    }

    Connections {
        target: Services.ShipLog

        function onSearchRequested(q: string): void {
            search.text = q;
            Services.ShipLog.pendingQuery = "";
            if (q !== "")
                root.selectGroup("");
        }

        function onSelectRequested(app: string): void {
            root.selectGroup(app);
            Services.ShipLog.pendingSelect = "";
        }

        function onRevealRequested(id: string): void {
            root.openEntry(id);
            Services.ShipLog.pendingReveal = "";
        }
    }

    function selectGroup(app: string): void {
        selectedGroup = app;
        selectedEntry = "";
        focusedGroup = app;
        focusedEntry = "";
        Qt.callLater(() => {
            if (selectedGroup !== "") {
                const c = canvas.groupCentre(selectedGroup);
                canvas.centerOn(c.x, c.y);
            } else {
                canvas.centerOnHub();
            }
        });
    }

    function openEntry(id: string): void {
        const e = Services.ShipLog.byId(id);
        if (!e)
            return;
        if (selectedGroup !== (e.app || "Unknown"))
            selectGroup(e.app || "Unknown");
        selectedEntry = id;
        focusedEntry = id;
        focusedGroup = selectedGroup;
        Services.ShipLog.markRead(id);
        const c = canvas.entryCentre(id);
        canvas.ensureVisible(c.x, c.y);
    }

    function moveGroup(delta: int): void {
        if (groups.length === 0)
            return;
        let i = groups.findIndex(g => g.app === focusedGroup);
        i = i < 0 ? (delta > 0 ? 0 : groups.length - 1) : (i + delta + groups.length) % groups.length;
        focusedGroup = groups[i].app;
        focusedEntry = "";
        const c = canvas.groupCentre(focusedGroup);
        canvas.ensureVisible(c.x, c.y);
    }

    function moveEntry(delta: int): void {
        const list = canvas.fanned;
        if (list.length === 0)
            return;
        let i = list.findIndex(e => e.id === focusedEntry);
        i = i < 0 ? (delta > 0 ? 0 : list.length - 1) : (i + delta + list.length) % list.length;
        focusedEntry = list[i].id;
        const c = canvas.entryCentre(focusedEntry);
        canvas.ensureVisible(c.x, c.y);
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
            if (focusedEntry !== "")
                moveEntry(-1);
            else
                moveGroup(-1);
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
            if (focusedEntry !== "")
                moveEntry(1);
            else
                moveGroup(1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (focusedEntry !== "") {
                openEntry(focusedEntry);
            } else if (focusedGroup !== "") {
                if (selectedGroup !== focusedGroup)
                    selectGroup(focusedGroup);
                if (canvas.fanned.length > 0)
                    focusedEntry = canvas.fanned[0].id;
            } else if (groups.length > 0) {
                moveGroup(1);
            }
            break;
        case Qt.Key_Backspace:
            if (focusedEntry !== "") {
                focusedEntry = "";
                selectedEntry = "";
            } else if (selectedGroup !== "") {
                selectGroup("");
            }
            break;
        case Qt.Key_Slash:
            search.forceFocus();
            break;
        case Qt.Key_P:
            if (selectedEntry)
                Services.ShipLog.togglePin(selectedEntry);
            break;
        case Qt.Key_Delete:
            if (selectedEntry) {
                const id = selectedEntry;
                selectedEntry = "";
                focusedEntry = "";
                Services.ShipLog.remove(id);
            }
            break;
        case Qt.Key_Escape:
            root.visibilities?.closeAll();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    NomaiFrame {
        anchors.fill: parent
        padding: Theme.spaceMd
        chamfer: Theme.chamferLg
        fill: Theme.ink1
        glow: true
        ticks: true

        GlyphReveal {
            id: revealer
            anchors.fill: parent
            autoTrigger: false

            Column {
                id: layout
                anchors.fill: parent
                spacing: Theme.spaceSm

                // ---- top bar ----
                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spaceSm

                        GlyphIcon {
                            icon: "hub"
                            color: Theme.line
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        GlyphText {
                            text: "Ship log"
                            role: "title"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        GlyphText {
                            text: `${Services.ShipLog.entries.length} signals · ${Services.ShipLog.unreadCount} unread` + (Services.ShipLog.rumorCount > 0 ? ` · ${Services.ShipLog.rumorCount} rumors` : "")
                            role: "label"
                            dim: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    NomaiTextField {
                        id: search
                        anchors.right: topRight.left
                        anchors.rightMargin: Theme.spaceMd
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 300
                        icon: "search"
                        placeholder: "Search signals  ( / )"
                        onAccepted: root.forceActiveFocus()
                        onEscaped: {
                            if (text !== "")
                                text = "";
                            root.forceActiveFocus();
                        }
                        Keys.onDownPressed: root.forceActiveFocus()
                    }

                    Row {
                        id: topRight
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spaceSm

                        HexButton {
                            icon: "done_all"
                            text: "Mark all read"
                            enabled: Services.ShipLog.unreadCount > 0 || Services.ShipLog.rumorCount > 0
                            onClicked: Services.ShipLog.markAllRead()
                        }

                        HexButton {
                            icon: "close"
                            flat: true
                            onClicked: root.visibilities?.closeAll()
                        }
                    }
                }

                // ---- filter chips ----
                Flow {
                    width: parent.width
                    spacing: Theme.spaceXs

                    HexButton {
                        icon: "release_alert"
                        text: "Critical"
                        active: root.filterCritical
                        accent: Theme.ember
                        padding: Theme.spaceXs
                        onClicked: root.filterCritical = !root.filterCritical
                    }

                    HexButton {
                        icon: "mark_email_unread"
                        text: "Unread"
                        active: root.filterUnread
                        padding: Theme.spaceXs
                        onClicked: root.filterUnread = !root.filterUnread
                    }

                    HexButton {
                        icon: "help"
                        text: "Rumors"
                        active: root.filterRumors
                        padding: Theme.spaceXs
                        onClicked: root.filterRumors = !root.filterRumors
                    }

                    Item { width: Theme.spaceSm; height: 1 }

                    Repeater {
                        model: root.groups.slice(0, 10)

                        HexButton {
                            required property var modelData
                            text: modelData.app
                            active: root.appFilter === modelData.app
                            flat: !active
                            padding: Theme.spaceXs
                            maxWidth: 130
                            onClicked: root.appFilter = root.appFilter === modelData.app ? "" : modelData.app
                        }
                    }

                    HexButton {
                        visible: root.filtering
                        icon: "filter_alt_off"
                        text: "Reset"
                        flat: true
                        padding: Theme.spaceXs
                        onClicked: {
                            root.appFilter = "";
                            root.filterCritical = false;
                            root.filterUnread = false;
                            root.filterRumors = false;
                            search.text = "";
                        }
                    }
                }

                // ---- map + detail ----
                Row {
                    width: parent.width
                    height: layout.height - y - hint.height - layout.spacing
                    spacing: Theme.spaceMd

                    NomaiFrame {
                        width: parent.width - detail.width - parent.spacing
                        height: parent.height
                        padding: 1
                        chamfer: Theme.chamferMd
                        fill: Theme.ink0
                        lineOpacity: 0.6

                        ShipLogCanvas {
                            id: canvas
                            anchors.fill: parent
                            groups: root.groups
                            edges: Services.ShipLog.edges
                            selectedGroup: root.selectedGroup
                            selectedEntry: root.selectedEntry
                            focusedGroup: root.focusedGroup
                            focusedEntry: root.focusedEntry
                            entryMatches: root.entryMatches
                            onHubClicked: root.selectGroup("")
                            onGroupClicked: app => root.selectGroup(root.selectedGroup === app ? "" : app)
                            onEntryClicked: id => root.openEntry(id)
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: root.groups.length === 0
                            spacing: Theme.spaceSm

                            GlyphIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: "explore"
                                color: Theme.lineDim
                                size: 40
                            }

                            GlyphText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "The log is empty. Signals appear here as notifications arrive."
                                role: "small"
                                dim: true
                            }
                        }
                    }

                    ShipLogDetail {
                        id: detail
                        width: 340
                        height: parent.height
                        entry: root.selectedEntryObj
                        group: root.selectedGroupObj
                    }
                }

                GlyphText {
                    id: hint
                    width: parent.width
                    text: "arrows move  ·  enter opens  ·  backspace back  ·  / search  ·  p pin  ·  del delete  ·  esc close"
                    role: "label"
                    dim: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
