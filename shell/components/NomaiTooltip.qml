import QtQuick
import qs.theme

// Chamfered label that appears after `delay` ms while `show` is true.
// The bubble is reparented to the top of the window so clip and later siblings
// cannot cover it. `place` is relative to `anchorItem` (the declaring parent).
Item {
    id: root

    property string text: ""
    property bool show: false
    property int delay: 500
    property Item anchorItem: null
    // below | above | left | right
    property string place: "below"
    // center | start | end, along the cross axis
    property string align: "center"
    property int gap: Theme.spaceXs

    width: 0
    height: 0
    visible: false

    function targetItem(): Item {
        return anchorItem !== null ? anchorItem : parent;
    }

    function overlayItem(): Item {
        let top = targetItem();
        let p = top ? top.parent : null;
        while (p) {
            top = p;
            p = p.parent;
        }
        return top;
    }

    function lift(): void {
        const host = overlayItem();
        if (host && bubble.parent !== host)
            bubble.parent = host;
        placeBubble();
    }

    function placeBubble(): void {
        const host = bubble.parent;
        const item = targetItem();
        if (!host || !item || host === root)
            return;
        const origin = item.mapToItem(host, 0, 0);
        const bw = bubble.width;
        const bh = bubble.height;
        let nx = 0;
        let ny = 0;
        if (place === "right") {
            nx = origin.x + item.width + gap;
            ny = align === "start" ? origin.y : (align === "end" ? origin.y + item.height - bh : origin.y + (item.height - bh) / 2);
        } else if (place === "left") {
            nx = origin.x - bw - gap;
            ny = align === "start" ? origin.y : (align === "end" ? origin.y + item.height - bh : origin.y + (item.height - bh) / 2);
        } else if (place === "above") {
            ny = origin.y - bh - gap;
            nx = align === "start" ? origin.x : (align === "end" ? origin.x + item.width - bw : origin.x + (item.width - bw) / 2);
        } else {
            ny = origin.y + item.height + gap;
            nx = align === "start" ? origin.x : (align === "end" ? origin.x + item.width - bw : origin.x + (item.width - bw) / 2);
        }
        bubble.x = Math.max(0, Math.min(nx, Math.max(0, host.width - bw)));
        bubble.y = Math.max(0, Math.min(ny, Math.max(0, host.height - bh)));
    }

    onShowChanged: {
        lift();
        if (show)
            shown.restart();
        else {
            shown.stop();
            bubble.revealed = false;
        }
    }

    Component.onCompleted: {
        if (show) {
            lift();
            shown.restart();
        }
    }
    Component.onDestruction: {
        if (bubble.parent !== root)
            bubble.destroy();
    }

    Timer {
        id: shown
        interval: root.delay
        onTriggered: bubble.revealed = true
    }

    Timer {
        interval: 16
        repeat: true
        running: root.show || bubble.opacity > 0
        onTriggered: {
            root.lift();
        }
    }

    NomaiFrame {
        id: bubble

        property bool revealed: false

        enabled: false
        visible: opacity > 0
        opacity: shown.running || revealed ? 1 : 0
        z: Theme.zTooltip
        padding: Theme.spaceSm
        chamfer: Theme.chamferSm
        fill: Theme.ink0
        lineOpacity: 0.8
        ticks: true

        GlyphText {
            text: root.text
            role: "small"
            wrapMode: Text.Wrap
            maximumLineCount: 4
        }

        onWidthChanged: root.placeBubble()
        onHeightChanged: root.placeBubble()

        Behavior on opacity {
            NumberAnimation { duration: Motion.fast }
        }
    }
}
