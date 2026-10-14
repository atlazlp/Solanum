pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// Dropdown over `model` ([ "a", "b" ] or [{ value, label }]). Emits activated(value);
// the caller writes it back into `currentValue`. The list opens in `overlay` (default: the
// top-most ancestor, i.e. the window content item) so it is never clipped by a Flickable.
Item {
    id: root

    property var model: []
    property var currentValue: undefined
    property string placeholder: "select"
    property Item overlay: null
    property int popupWidth: 0          // 0 = same as the combo
    property int maxPopupHeight: 260
    readonly property bool open: popup !== null
    property var popup: null

    signal activated(var value)

    implicitWidth: 200
    implicitHeight: 30
    activeFocusOnTab: true

    function valueOf(entry: var): var {
        return entry !== null && typeof entry === "object" ? entry.value : entry;
    }

    function labelOf(entry: var): string {
        return entry !== null && typeof entry === "object" ? String(entry.label ?? entry.value) : String(entry);
    }

    function currentLabel(): string {
        const e = model.find(m => valueOf(m) === currentValue);
        return e !== undefined ? labelOf(e) : (currentValue === undefined || currentValue === "" ? "" : String(currentValue));
    }

    function overlayItem(): Item {
        if (overlay)
            return overlay;
        let p = root;
        while (p.parent)
            p = p.parent;
        return p;
    }

    function toggle(): void {
        if (popup)
            close();
        else
            openPopup();
    }

    function openPopup(): void {
        if (popup || model.length === 0)
            return;
        const host = overlayItem();
        const pos = root.mapToItem(host, 0, root.height + Theme.spaceXs);
        const w = popupWidth > 0 ? popupWidth : root.width;
        const h = Math.min(maxPopupHeight, model.length * 30 + Theme.spaceSm * 2 + 2);
        popup = popupComp.createObject(host, {
            x: Math.max(0, Math.min(pos.x, host.width - w)),
            y: pos.y + h > host.height ? Math.max(0, root.mapToItem(host, 0, 0).y - h - Theme.spaceXs) : pos.y,
            width: w,
            height: h
        });
        popup.forceActiveFocus();
    }

    function close(): void {
        if (!popup)
            return;
        const hadFocus = popup.activeFocus;
        popup.destroy();
        popup = null;
        // The popup held active focus; hand it back so Escape/Tab keep working in the panel.
        if (hadFocus)
            root.forceActiveFocus();
    }

    function pick(entry: var): void {
        close();
        root.activated(valueOf(entry));
    }

    Component.onDestruction: close()
    onVisibleChanged: if (!visible) close()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            toggle();
            event.accepted = true;
        }
    }

    NomaiFrame {
        anchors.fill: parent
        padding: 0
        chamfer: Theme.chamferSm
        fill: hover.hovered || root.open ? Theme.ink2 : Theme.ink0
        lineOpacity: hover.hovered || root.open || root.activeFocus ? 1 : 0.6
        glow: root.open || root.activeFocus
        ticks: true

        GlyphText {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.right: chevron.left
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel() || root.placeholder
            dim: root.currentLabel() === ""
        }

        GlyphIcon {
            id: chevron
            icon: root.open ? "expand_less" : "expand_more"
            color: Theme.textDim
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.toggle()
    }

    Component {
        id: popupComp

        Item {
            id: pop

            z: Theme.zModal + 5
            focus: true

            Keys.onEscapePressed: root.close()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: if (list.currentIndex >= 0) root.pick(root.model[list.currentIndex])

            // Click-away catcher covering the whole overlay.
            Item {
                x: -pop.x
                y: -pop.y
                width: pop.parent ? pop.parent.width : 0
                height: pop.parent ? pop.parent.height : 0
                z: -1

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onTapped: root.close()
                }
            }

            NomaiFrame {
                anchors.fill: parent
                padding: Theme.spaceSm
                chamfer: Theme.chamferSm
                fill: Theme.ink1
                glow: true
                ticks: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 1
                    model: root.model
                    currentIndex: root.model.findIndex(m => root.valueOf(m) === root.currentValue)
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: opt
                        required property var modelData
                        required property int index
                        readonly property bool selected: root.valueOf(modelData) === root.currentValue

                        width: list.width
                        height: 29

                        NomaiFrame {
                            anchors.fill: parent
                            padding: 0
                            chamfer: Theme.chamferSm
                            lineOpacity: optHover.hovered || list.currentIndex === opt.index ? 0.8 : 0
                            fill: optHover.hovered ? Theme.ink2 : (opt.selected ? Theme.alpha(Theme.line, 0.12) : "transparent")
                        }

                        GlyphText {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceSm
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.labelOf(opt.modelData)
                            color: opt.selected ? Theme.line : Theme.text
                        }

                        HoverHandler {
                            id: optHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: root.pick(opt.modelData)
                        }
                    }
                }
            }
        }
    }
}
