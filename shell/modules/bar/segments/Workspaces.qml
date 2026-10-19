pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.theme
import qs.components
import qs.services

// Replaces workspace hex pips: unread notifications + special-workspace (scratchpad) indicator.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    interactive: false
    padding: Theme.spaceXs
    readonly property real iconSize: Theme.sizeIcon * 1.1

    readonly property int unread: ShipLog.unreadCount
    readonly property HyprlandMonitor monitor: screen ? Hypr.monitorFor(screen) : null

    readonly property var specialWs: {
        void Hypr.workspaces.values;
        return Hypr.workspaces.values.find(w => {
            const n = w.name ?? "";
            return n === "special:special" || n === "special";
        }) ?? null;
    }

    readonly property int specialCount: {
        void Hypr.workspaces.values;
        void Hypr.toplevels.values;
        const ws = root.specialWs;
        if (!ws)
            return 0;
        const ipc = ws.lastIpcObject?.windows;
        if (typeof ipc === "number")
            return ipc;
        return ws.toplevels?.values?.length ?? 0;
    }

    readonly property bool specialOpen: {
        const m = root.monitor;
        if (!m)
            return false;
        const n = m.lastIpcObject?.specialWorkspace?.name
            ?? m.activeSpecialWorkspace?.name
            ?? "";
        return n === "special:special" || n === "special" || String(n).startsWith("special:");
    }

    Column {
        spacing: Theme.spaceSm
        anchors.horizontalCenter: parent.horizontalCenter

        // Unread ship-log / notifications
        Item {
            id: notifBtn
            width: root.iconSize
            height: width
            anchors.horizontalCenter: parent.horizontalCenter

            GlyphIcon {
                anchors.centerIn: parent
                icon: root.unread > 0 ? "notifications_active" : "notifications"
                size: Theme.sizeIcon
                fill: root.unread > 0 ? 1 : 0
                color: notifHover.hovered || root.unread > 0 ? Theme.spark : Theme.textDim
                animate: true
            }

            Rectangle {
                visible: root.unread > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -6
                anchors.topMargin: -4
                width: Math.max(15, badgeText.implicitWidth + 7)
                height: 15
                radius: 2
                // High contrast against spark/ember icons: dark chip + bright count.
                color: Theme.ink0
                border.width: 1
                border.color: Theme.line

                GlyphText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.unread > 99 ? "99+" : `${root.unread}`
                    role: "label"
                    font.letterSpacing: 0
                    font.pointSize: 9
                    font.weight: Font.Bold
                    color: Theme.line
                }
            }

            HoverHandler {
                id: notifHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    root.bar?.popouts?.hide();
                    Visibilities.toggle("shipLog", root.bar?.visibilities ?? null);
                }
            }

            NomaiTooltip {
                text: root.unread > 0 ? `${root.unread} unread` : "Ship log"
                show: notifHover.hovered
                place: "right"
                gap: Theme.spaceSm
            }
        }

        // Special workspace / scratchpad (Super+S, Ctrl+Super+Space)
        Item {
            id: specialBtn
            width: root.iconSize
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.specialCount > 0 || root.specialOpen || specialHover.hovered ? 1 : 0.35

            GlyphIcon {
                anchors.centerIn: parent
                icon: root.specialOpen ? "flip_to_front" : "layers"
                size: Theme.sizeIcon
                fill: root.specialOpen || root.specialCount > 0 ? 1 : 0
                color: {
                    if (root.specialOpen)
                        return Theme.spark;
                    if (root.specialCount > 0)
                        return Theme.secondary;
                    return specialHover.hovered ? Theme.spark : Theme.textDim;
                }
                animate: true
            }

            Rectangle {
                visible: root.specialCount > 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -1
                anchors.bottomMargin: -1
                width: Math.max(12, specialBadge.implicitWidth + 5)
                height: 12
                color: root.specialOpen ? Theme.spark : Theme.secondary

                GlyphText {
                    id: specialBadge
                    anchors.centerIn: parent
                    text: root.specialCount > 9 ? "9+" : `${root.specialCount}`
                    role: "label"
                    font.letterSpacing: 0
                    font.pointSize: 8
                    color: Theme.ink0
                }
            }

            HoverHandler {
                id: specialHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    if (root.monitor)
                        Hypr.dispatch(`focusmonitor ${root.monitor.name}`);
                    Hypr.dispatch("togglespecialworkspace special");
                }
            }

            NomaiTooltip {
                text: root.specialCount > 0
                    ? `Special · ${root.specialCount} window${root.specialCount === 1 ? "" : "s"}`
                    : "Special workspace"
                show: specialHover.hovered
                place: "right"
                gap: Theme.spaceSm
            }
        }
    }
}
