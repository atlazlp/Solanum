pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// Vertical navigation rail of chamfered tabs with a hex pip on the active one.
// model: [{ id, label, icon }]. `current` is the active id; `selected(id)` fires on click / keys.
Item {
    id: root

    property var model: []
    property string current: ""
    property int tabHeight: 38
    signal selected(string id)

    implicitWidth: 200
    implicitHeight: column.implicitHeight
    activeFocusOnTab: true

    function indexOf(id: string): int {
        return model.findIndex(t => t.id === id);
    }

    function move(delta: int): void {
        if (model.length === 0)
            return;
        const i = indexOf(current);
        const n = i < 0 ? 0 : (i + delta + model.length) % model.length;
        root.selected(model[n].id);
    }

    Keys.onUpPressed: move(-1)
    Keys.onDownPressed: move(1)

    Column {
        id: column
        width: parent.width
        spacing: 2

        Repeater {
            model: root.model

            Item {
                id: tab

                required property var modelData
                required property int index
                readonly property bool active: root.current === modelData.id
                readonly property bool hot: hover.hovered || (root.activeFocus && active)

                width: column.width
                height: root.tabHeight

                NomaiFrame {
                    anchors.fill: parent
                    padding: 0
                    chamfer: Theme.chamferSm
                    corners: 5
                    lineColor: Theme.line
                    lineOpacity: tab.active || tab.hot ? 1 : 0
                    glow: tab.active && root.activeFocus
                    fill: {
                        if (flash.running)
                            return Theme.alpha(Theme.lineSoft, 0.14);
                        if (tab.active)
                            return Theme.alpha(Theme.line, 0.14);
                        if (hover.hovered)
                            return Theme.ink2;
                        return "transparent";
                    }
                }

                // Active marker: a hex pip on the left edge.
                NomaiFrame {
                    width: Theme.hexPip
                    height: Theme.hexPip
                    shape: "hex"
                    padding: 0
                    fill: tab.active ? Theme.line : "transparent"
                    lineColor: Theme.line
                    lineOpacity: tab.active ? 1 : 0
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceSm
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceSm * 2 + Theme.hexPip
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceSm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceSm

                    GlyphIcon {
                        visible: (tab.modelData.icon ?? "") !== ""
                        icon: tab.modelData.icon ?? ""
                        fill: tab.active ? 1 : 0
                        size: Theme.sizeIcon
                        color: tab.active ? Theme.line : Theme.text
                        animate: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    GlyphText {
                        text: tab.modelData.label ?? tab.modelData.id
                        role: "body"
                        color: tab.active ? Theme.line : Theme.text
                        animate: true
                        width: parent.width - Theme.sizeIcon * 1.5 - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        flash.restart();
                        root.selected(tab.modelData.id);
                    }
                }

                Timer {
                    id: flash
                    interval: Motion.press
                }
            }
        }
    }
}
