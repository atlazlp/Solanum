pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.theme
import qs.components
import qs.services
import "../../../theme/Glyphs.js" as Glyphs

// Hex pips for this monitor's workspaces (occupied / active / urgent). Scroll switches, click dispatches.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    readonly property HyprlandMonitor monitor: screen ? Hypr.monitorFor(screen) : null
    readonly property int shown: Config.bar.workspaces.shown ?? 5
    readonly property bool perMonitor: Config.bar.workspaces.perMonitorWorkspaces !== false
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1

    // Workspace ids to show: existing (non-special) workspaces on this monitor, padded to `shown`.
    readonly property list<int> ids: {
        void Hypr.workspaces.values;
        const mine = Hypr.workspaces.values.filter(w => w.id > 0 && (!perMonitor || w.monitor?.name === monitor?.name)).map(w => w.id).sort((a, b) => a - b);
        const out = mine.slice();
        let next = out.length ? out[out.length - 1] + 1 : 1;
        if (!perMonitor && out.length === 0)
            next = 1;
        while (out.length < shown) {
            if (!out.includes(next))
                out.push(next);
            next++;
        }
        return out;
    }

    function workspaceOf(id: int): HyprlandWorkspace {
        return Hypr.workspaces.values.find(w => w.id === id) ?? null;
    }

    function go(id: int): void {
        if (monitor)
            Hypr.dispatch(`focusmonitor ${monitor.name}`);
        Hypr.dispatch(`workspace ${id}`);
    }

    onWheel: event => {
        if (!monitor)
            return;
        Hypr.dispatch(`focusmonitor ${monitor.name}`);
        if (event.angleDelta.y < 0)
            Hypr.dispatch("workspace r+1");
        else if (event.angleDelta.y > 0)
            Hypr.dispatch("workspace r-1");
    }

    Row {
        id: pips
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.ids

            Item {
                id: pip

                required property int modelData
                readonly property HyprlandWorkspace ws: root.workspaceOf(modelData)
                readonly property bool exists: ws !== null
                readonly property bool occupied: exists && ((ws.lastIpcObject?.windows ?? 0) > 0 || ws.toplevels.values.length > 0)
                readonly property bool active: modelData === root.activeId
                readonly property bool urgent: exists && ws.urgent
                readonly property real rad: (Theme.hexPip + (active ? 3 : 0)) / 2

                width: Theme.hexPip + 6
                height: Theme.hexPip + 6
                anchors.verticalCenter: parent.verticalCenter

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: pip.active ? Theme.line : (pip.occupied ? Theme.alpha(Theme.line, 0.3) : "transparent")
                        strokeColor: pip.urgent ? Theme.ember : (pip.active || pip.occupied ? Theme.line : Theme.lineDim)
                        strokeWidth: pip.urgent ? 1.5 : 1
                        joinStyle: ShapePath.MiterJoin
                        PathSvg { path: Glyphs.hexPip(pip.width / 2, pip.height / 2, pip.rad) }

                        Behavior on fillColor {
                            ColorAnimation { duration: Motion.fast }
                        }
                    }
                }

                GlyphText {
                    anchors.centerIn: parent
                    visible: hh.hovered
                    text: pip.modelData
                    role: "label"
                    font.letterSpacing: 0
                    color: pip.active ? Theme.textOnLine : Theme.text
                }

                HoverHandler {
                    id: hh
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.go(pip.modelData)
                }
            }
        }
    }
}
