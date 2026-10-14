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

    interactive: false
    visible: items.length > 0
    implicitWidth: visible ? itemsRow.implicitWidth + padding * 2 + leftSlant + rightSlant : 0

    Row {
        id: itemsRow
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.items

            Item {
                id: trayItem

                required property SystemTrayItem modelData
                readonly property bool menuOpen: (root.bar?.popouts?.hasCurrent ?? false) && root.bar.popouts.currentName === "tray" && root.bar.popouts.payload === modelData

                width: Theme.sizeIcon * 1.2
                height: width
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    anchors.fill: parent
                    source: Icons.getTrayIcon(trayItem.modelData.icon)
                    implicitSize: parent.width
                    asynchronous: true
                    opacity: hover.hovered || trayItem.menuOpen ? 1 : 0.8
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: 1
                    color: Theme.line
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
                                host.show("tray", trayItem.mapToItem(null, 0, 0).x, trayItem.width, item, true);
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
                    anchors.top: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: Theme.spaceSm
                }
            }
        }
    }
}
