pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Selection surface for one screen. Hover snaps to the toplevel under the cursor, drag draws a free
// rectangle (edges snap to nearby window edges), Enter / release captures, Escape cancels.
MouseArea {
    id: root

    required property ShellScreen screen

    readonly property bool freeze: Screenshot.freeze
    readonly property bool clipboardOnly: Screenshot.clipboardOnly
    readonly property int snapDist: 12
    // In freeze mode the chrome stays hidden until the frozen frame exists, so the screencopy
    // never includes our own overlay.
    readonly property bool ready: !freeze || (screencopy.item?.hasContent ?? false)

    property bool onClient: false
    property bool dragging: false
    property real ssx: 0
    property real ssy: 0

    // Start empty so Enter before onCompleted cannot capture a full-monitor rect by accident.
    property real sx: 0
    property real sy: 0
    property real ex: 0
    property real ey: 0
    property bool selectionReady: false

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    // Toplevels on this monitor's active (or special) workspace, as screen-local rects.
    property list<var> clients: {
        const mon = Hypr.monitorFor(screen);
        if (!mon)
            return [];
        const special = mon.lastIpcObject?.specialWorkspace;
        const wsId = special?.name ? special.id : mon.activeWorkspace?.id;
        const sorted = Hypr.toplevels.values.filter(c => c.lastIpcObject && c.workspace?.id === wsId).sort((a, b) => {
            const ac = a.lastIpcObject, bc = b.lastIpcObject;
            return ((bc.pinned ? 1 : 0) - (ac.pinned ? 1 : 0)) || ((bc.fullscreen ? 1 : 0) - (ac.fullscreen ? 1 : 0)) || ((bc.floating ? 1 : 0) - (ac.floating ? 1 : 0));
        });
        return sorted.map(c => ({
            x: c.lastIpcObject.at[0] - screen.x,
            y: c.lastIpcObject.at[1] - screen.y,
            w: c.lastIpcObject.size[0],
            h: c.lastIpcObject.size[1]
        }));
    }

    function clientAt(x: real, y: real): var {
        for (const c of clients)
            if (c.x <= x && c.y <= y && c.x + c.w >= x && c.y + c.h >= y)
                return c;
        return null;
    }

    function checkClientRects(x: real, y: real): void {
        const c = clientAt(x, y);
        if (c) {
            onClient = true;
            sx = c.x;
            sy = c.y;
            ex = c.x + c.w;
            ey = c.y + c.h;
        }
    }

    function snapX(v: real): real {
        let best = v, d = snapDist;
        for (const c of clients)
            for (const e of [c.x, c.x + c.w])
                if (Math.abs(e - v) < d) {
                    d = Math.abs(e - v);
                    best = e;
                }
        return best;
    }

    function snapY(v: real): real {
        let best = v, d = snapDist;
        for (const c of clients)
            for (const e of [c.y, c.y + c.h])
                if (Math.abs(e - v) < d) {
                    d = Math.abs(e - v);
                    best = e;
                }
        return best;
    }

    function capture(): void {
        if (Screenshot.closing || Screenshot.capturing || !selectionReady)
            return;
        if (sw < 2 || sh < 2)
            return;
        Screenshot.capturing = true;
        captureTimer.restart();
    }

    function cancel(): void {
        if (!Screenshot.closing)
            Screenshot.close();
    }

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    focus: true
    opacity: Screenshot.closing ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.normal
            easing.type: Motion.fade
        }
    }

    Component.onCompleted: {
        Hypr.refreshAll();
        if (freeze)
            clients = clients;   // break the binding: keep the rects as they were when frozen
        // Never pre-select a window — user must drag or hover a window, then confirm.
        onClient = false;
        sx = screen.width / 2 - 160;
        sy = screen.height / 2 - 100;
        ex = screen.width / 2 + 160;
        ey = screen.height / 2 + 100;
        selectionReady = true;
        forceActiveFocus();
    }

    onPressed: event => {
        if (event.button === Qt.RightButton) {
            cancel();
            return;
        }
        ssx = event.x;
        ssy = event.y;
        dragging = false;
    }

    onReleased: event => {
        if (event.button !== Qt.LeftButton)
            return;
        if (dragging && sw >= 2 && sh >= 2)
            capture();
        else if (!dragging && onClient)
            capture();
        dragging = false;
    }

    onPositionChanged: event => {
        if (pressed) {
            if (!dragging && Math.hypot(event.x - ssx, event.y - ssy) < 3)
                return;
            dragging = true;
            onClient = false;
            sx = snapX(ssx);
            sy = snapY(ssy);
            ex = snapX(event.x);
            ey = snapY(event.y);
        } else {
            checkClientRects(event.x, event.y);
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            cancel();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            capture();
            event.accepted = true;
        } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            onClient = false;
            sx = 0;
            sy = 0;
            ex = screen.width;
            ey = screen.height;
            event.accepted = true;
        }
    }

    Timer {
        id: captureTimer
        interval: 120
        onTriggered: {
            Screenshot.capture(root.screen.x + Math.ceil(root.rsx), root.screen.y + Math.ceil(root.rsy), Math.floor(root.sw), Math.floor(root.sh), "", root.clipboardOnly);
            Screenshot.close();
        }
    }

    Process {
        running: true
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pos = JSON.parse(text);
                    root.checkClientRects(pos.x - root.screen.x, pos.y - root.screen.y);
                } catch (e) {}
            }
        }
    }

    // Frozen frame (freeze mode only).
    Loader {
        id: screencopy
        anchors.fill: parent
        active: root.freeze
        sourceComponent: ScreencopyView {
            captureSource: root.screen
            live: false
        }
    }

    // Everything below is hidden while grim captures.
    Item {
        id: chrome

        anchors.fill: parent
        visible: !Screenshot.capturing && opacity > 0
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.normal; easing.type: Motion.fade } }

        // Dim everything except the selection (four rects, no mask effects).
        Rectangle { color: Theme.scrim; x: 0; y: 0; width: parent.width; height: sel.y }
        Rectangle { color: Theme.scrim; x: 0; y: sel.y + sel.height; width: parent.width; height: parent.height - sel.y - sel.height }
        Rectangle { color: Theme.scrim; x: 0; y: sel.y; width: sel.x; height: sel.height }
        Rectangle { color: Theme.scrim; x: sel.x + sel.width; y: sel.y; width: parent.width - sel.x - sel.width; height: sel.height }

        Item {
            id: sel

            x: root.rsx
            y: root.rsy
            width: root.sw
            height: root.sh

            Behavior on x { enabled: !root.pressed; NumberAnimation { duration: Motion.normal; easing.type: Motion.slide } }
            Behavior on y { enabled: !root.pressed; NumberAnimation { duration: Motion.normal; easing.type: Motion.slide } }
            Behavior on width { enabled: !root.pressed; NumberAnimation { duration: Motion.normal; easing.type: Motion.slide } }
            Behavior on height { enabled: !root.pressed; NumberAnimation { duration: Motion.normal; easing.type: Motion.slide } }

            // Outer glow + 1 px line
            Rectangle {
                anchors.fill: parent
                anchors.margins: -Theme.glowWidth / 2
                color: "transparent"
                border.width: Theme.glowWidth
                border.color: Theme.glow
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: Theme.lineWidth
                border.color: root.onClient ? Theme.spark : Theme.line
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }

            // Corner ticks
            Shape {
                anchors.fill: parent
                anchors.margins: -4
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.onClient ? Theme.spark : Theme.line
                    strokeWidth: 2
                    capStyle: ShapePath.FlatCap
                    PathSvg { path: Glyphs.cornerTicks(sel.width + 8, sel.height + 8, 12, 1) }
                }
            }

            // Size label (mono), below the selection or inside it when there is no room.
            NomaiFrame {
                id: label

                readonly property bool below: sel.y + sel.height + implicitHeight + 10 < root.height
                x: 0
                y: below ? sel.height + 8 : sel.height - implicitHeight - 8
                padding: Theme.spaceXs
                chamfer: Theme.chamferSm
                fill: Theme.ink0
                lineOpacity: 0.7
                glow: false

                GlyphText {
                    role: "mono"
                    text: `${Math.round(root.sw)} × ${Math.round(root.sh)}` + (root.onClient ? "  window" : "")
                    color: Theme.text
                }
            }
        }

    }
}
