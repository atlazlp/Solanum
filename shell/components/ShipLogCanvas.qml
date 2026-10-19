pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.theme
import qs.utils

// Pannable ship-log map. App groups sit on two rings around the hub (inner ring = most recent);
// selecting a group fans its entries out on an arc facing away from the hub. Edges: hub spokes
// and (for the selected group) each fanned entry linked only to its parent group.
Flickable {
    id: root

    property list<var> groups: []       // ShipLog.groups
    property list<var> edges: []        // ShipLog.edges
    property string selectedGroup: ""
    property string selectedEntry: ""
    property string focusedGroup: ""
    property string focusedEntry: ""
    property var entryMatches: null     // (entry) => bool; null = everything matches
    property int innerRadius: 260
    property int outerRadius: 420
    property int fanRadius: 150
    property int maxFan: 16
    property int maxInner: 8

    signal hubClicked()
    signal groupClicked(string app)
    signal entryClicked(string id)

    readonly property real hubX: contentWidth / 2
    readonly property real hubY: contentHeight / 2

    function matches(e: var): bool {
        return entryMatches === null || entryMatches(e);
    }

    function groupMatches(g: var): bool {
        return entryMatches === null || g.entries.some(e => entryMatches(e));
    }

    // Entries shown when a group is selected: matching first, newest first, capped.
    readonly property list<var> fanned: {
        const g = groups.find(x => x.app === selectedGroup);
        if (!g)
            return [];
        const list = g.entries.filter(e => matches(e));
        return list.slice(0, maxFan);
    }

    readonly property var layout: {
        const pos = {};
        const n = groups.length;
        const innerCount = Math.min(n, n <= 6 ? n : Math.max(Math.ceil(n / 2), 1), maxInner);
        const outerCount = n - innerCount;
        for (let i = 0; i < innerCount; i++) {
            const a = -Math.PI / 2 + (2 * Math.PI * i) / innerCount;
            pos[groups[i].app] = { x: hubX + Math.cos(a) * innerRadius, y: hubY + Math.sin(a) * innerRadius, angle: a };
        }
        for (let i = 0; i < outerCount; i++) {
            const a = -Math.PI / 2 + Math.PI / outerCount + (2 * Math.PI * i) / outerCount;
            pos[groups[innerCount + i].app] = { x: hubX + Math.cos(a) * outerRadius, y: hubY + Math.sin(a) * outerRadius, angle: a };
        }
        const epos = {};
        const sel = pos[selectedGroup];
        if (sel && fanned.length > 0) {
            const count = fanned.length;
            const perArc = 8;
            for (let i = 0; i < count; i++) {
                const arc = Math.floor(i / perArc);
                const idx = i % perArc;
                const inArc = Math.min(perArc, count - arc * perArc);
                const spread = Math.min(Math.PI * 0.9, (inArc - 1) * 0.6);
                const a = sel.angle - spread / 2 + (inArc === 1 ? spread / 2 : (spread * idx) / (inArc - 1));
                const r = fanRadius + arc * 100;
                epos[fanned[i].id] = { x: sel.x + Math.cos(a) * r, y: sel.y + Math.sin(a) * r };
            }
        }
        return { groupPos: pos, entryPos: epos };
    }

    readonly property list<var> drawnEdges: {
        const out = [];
        const gp = layout.groupPos;
        const ep = layout.entryPos;
        const sel = selectedGroup;
        for (const g of groups) {
            const p = gp[g.app];
            if (p)
                out.push({ key: `spoke:${g.app}`, from: Qt.point(hubX, hubY), to: Qt.point(p.x, p.y), rumor: g.rumors === g.count, highlighted: g.app === sel, dimmed: !groupMatches(g) });
        }
        if (sel && fanned.length > 0) {
            const g = gp[sel];
            if (g) {
                for (const e of fanned) {
                    const p = ep[e.id];
                    if (!p)
                        continue;
                    out.push({ key: `parent:${e.id}`, from: Qt.point(g.x, g.y), to: Qt.point(p.x, p.y), rumor: !!e.rumor, highlighted: true, dimmed: !matches(e) });
                }
            }
        }
        return out;
    }

    function centerOnHub(): void {
        contentX = hubX - width / 2;
        contentY = hubY - height / 2;
    }

    function centerOn(x: real, y: real): void {
        contentX = Math.max(0, Math.min(contentWidth - width, x - width / 2));
        contentY = Math.max(0, Math.min(contentHeight - height, y - height / 2));
    }

    function ensureVisible(x: real, y: real): void {
        const margin = 80;
        if (x - margin < contentX || x + margin > contentX + width || y - margin < contentY || y + margin > contentY + height)
            centerOn(x, y);
    }

    function groupCentre(app: string): point {
        const p = layout.groupPos[app];
        return p ? Qt.point(p.x, p.y) : Qt.point(hubX, hubY);
    }

    function entryCentre(id: string): point {
        const p = layout.entryPos[id];
        return p ? Qt.point(p.x, p.y) : groupCentre(selectedGroup);
    }

    contentWidth: outerRadius * 2 + 520
    contentHeight: outerRadius * 2 + 520
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 3000
    maximumFlickVelocity: 2500

    Behavior on contentX {
        enabled: !root.dragging && !root.flicking
        NumberAnimation { duration: Motion.slow; easing.type: Motion.slide }
    }
    Behavior on contentY {
        enabled: !root.dragging && !root.flicking
        NumberAnimation { duration: Motion.slow; easing.type: Motion.slide }
    }

    property bool centred: false

    onWidthChanged: {
        if (!centred && width > 0 && height > 0) {
            centred = true;
            centerOnHub();
        }
    }
    onHeightChanged: {
        if (!centred && width > 0 && height > 0) {
            centred = true;
            centerOnHub();
        }
    }

    // Faint ring guides.
    Repeater {
        model: [root.innerRadius, root.outerRadius]

        Rectangle {
            required property int modelData
            x: root.hubX - modelData
            y: root.hubY - modelData
            width: modelData * 2
            height: modelData * 2
            radius: modelData
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.lineDim, 0.25)
            z: -1
        }
    }

    Repeater {
        model: root.drawnEdges

        ShipLogEdge {
            required property var modelData
            from: modelData.from
            to: modelData.to
            rumor: modelData.rumor
            highlighted: modelData.highlighted
            dimmed: modelData.dimmed
        }
    }

    ShipLogNode {
        kind: "hub"
        cx: root.hubX
        cy: root.hubY
        glyph: "rocket_launch"
        label: "ship"
        selected: root.selectedGroup === ""
        onClicked: root.hubClicked()
    }

    Repeater {
        model: root.groups

        ShipLogNode {
            id: gnode
            required property var modelData
            readonly property string iconPath: {
                const ic = modelData.icon;
                if (ic && (ic.startsWith("/") || ic.startsWith("file://")))
                    return ic;
                const p = ic ? Quickshell.iconPath(ic, true) : "";
                return p || Icons.getAppIcon(modelData.desktopEntry || modelData.app, "");
            }
            kind: "group"
            cx: root.layout.groupPos[modelData.app]?.x ?? root.hubX
            cy: root.layout.groupPos[modelData.app]?.y ?? root.hubY
            label: modelData.app
            iconSource: iconPath
            glyph: Icons.getNotifIcon(modelData.entries[0]?.summary ?? "", false)
            count: modelData.count
            unread: modelData.unread > 0
            rumor: modelData.rumors === modelData.count
            selected: root.selectedGroup === modelData.app
            focused: root.focusedGroup === modelData.app && root.focusedEntry === ""
            dimmed: !root.groupMatches(modelData)
            onClicked: root.groupClicked(modelData.app)
        }
    }

    Repeater {
        model: root.fanned

        ShipLogNode {
            required property var modelData
            kind: "entry"
            cx: root.layout.entryPos[modelData.id]?.x ?? root.hubX
            cy: root.layout.entryPos[modelData.id]?.y ?? root.hubY
            label: Fmt.truncate(modelData.summary || modelData.body || "(no text)", 28)
            glyph: Icons.getNotifIcon(modelData.summary, modelData.urgency === 2)
            unread: !modelData.read
            rumor: !!modelData.rumor
            critical: modelData.urgency === 2
            pinned: !!modelData.pinned
            selected: root.selectedEntry === modelData.id
            focused: root.focusedEntry === modelData.id
            dimmed: !root.matches(modelData)
            labelWidth: 110
            onClicked: root.entryClicked(modelData.id)
        }
    }
}
