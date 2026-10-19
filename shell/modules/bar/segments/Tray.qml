pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils

// StatusNotifier items. Left click activates, right click opens the DBusMenu popout, middle = secondary, scroll forwarded.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    readonly property list<var> items: SystemTray.items.values.filter(i => !(Config.bar.tray.hiddenIcons ?? []).includes(i.id))

    readonly property real iconSize: Theme.sizeIcon * 1.15
    readonly property real accentIconSize: Theme.sizeIcon * 1.4

    function isAccentTray(item: var): bool {
        const id = String(item?.id ?? "").toLowerCase();
        const title = String(item?.title ?? "").toLowerCase();
        const tip = String(item?.tooltipTitle ?? "").toLowerCase();
        const icon = String(item?.icon ?? "").toLowerCase();
        return id.includes("lan-mouse") || id.includes("local-llm")
            || title.includes("lan kvm") || title.includes("local llm")
            || tip.includes("lan kvm") || tip.includes("local llm") || tip.includes("lan-mouse")
            || icon.includes("lan-kvm") || icon.includes("llm-");
    }

    interactive: false
    visible: items.length > 0
    padding: Theme.spaceXs
    implicitWidth: visible ? accentIconSize + padding * 2 : 0
    implicitHeight: visible ? itemsCol.implicitHeight + padding * 2 + startSlant + endSlant : 0

    Column {
        id: itemsCol
        spacing: Theme.spaceXs
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            model: root.items

            Item {
                id: trayItem

                required property SystemTrayItem modelData
                readonly property bool menuOpen: (root.bar?.popouts?.hasCurrent ?? false) && root.bar.popouts.currentName === "tray" && root.bar.popouts.payload === modelData
                readonly property bool accent: root.isAccentTray(modelData)
                readonly property real size: accent ? root.accentIconSize : root.iconSize

                width: trayItem.size
                height: width
                anchors.horizontalCenter: parent.horizontalCenter

                IconImage {
                    anchors.fill: parent
                    source: Icons.getTrayIcon(trayItem.modelData.icon)
                    implicitSize: parent.width
                    asynchronous: true
                    opacity: hover.hovered || trayItem.menuOpen ? 1 : 0.8
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: parent.height
                    color: Theme.spark
                    visible: trayItem.menuOpen
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (!hovered && trayItem.menuOpen)
                            root.bar.popouts.scheduleHide();
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: (point, button) => {
                        const item = trayItem.modelData;
                        const host = root.bar?.popouts;
                        if (button === Qt.RightButton || (button === Qt.LeftButton && item.onlyMenu)) {
                            if (!item.hasMenu || !host)
                                return;
                            if (trayItem.menuOpen)
                                host.hide();
                            else
                                host.show("tray", trayItem.mapToItem(null, 0, 0).y, trayItem.height, item, true);
                        } else if (button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else {
                            item.activate();
                        }
                    }
                }

                WheelHandler {
                    onWheel: event => trayItem.modelData.scroll(event.angleDelta.y, false)
                }

                NomaiTooltip {
                    text: trayItem.modelData.tooltipTitle || trayItem.modelData.title
                    show: hover.hovered && !trayItem.menuOpen
                    place: "right"
                    gap: Theme.spaceSm
                }
            }
        }
    }
}
