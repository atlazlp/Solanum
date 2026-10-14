pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services as Services
import qs.utils

// Right pane of the ship log: the selected entry (body, image, time, actions, pin, delete) or,
// with only a group selected, that group's summary.
Item {
    id: root

    property var entry: null        // ship-log entry object
    property var group: null        // ship-log group object
    readonly property bool live: entry ? Services.ShipLog.isOpen(entry) : false
    readonly property string iconSrc: {
        const ic = entry?.icon ?? group?.icon ?? "";
        if (ic && (ic.startsWith("/") || ic.startsWith("file://")))
            return ic;
        const p = ic ? Quickshell.iconPath(ic, true) : "";
        return p || Icons.getAppIcon(entry?.desktopEntry || group?.desktopEntry || entry?.app || group?.app || "", "");
    }

    signal closeRequested()

    implicitWidth: 340

    NomaiFrame {
        anchors.fill: parent
        padding: Theme.spaceMd
        chamfer: Theme.chamferMd
        fill: Theme.ink0
        lineOpacity: 0.6
        ticks: true

        Flickable {
            anchors.fill: parent
            contentHeight: content.implicitHeight
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: parent.width
                spacing: Theme.spaceMd

                // ---- empty ----
                Column {
                    width: parent.width
                    visible: !root.entry && !root.group
                    spacing: Theme.spaceSm
                    topPadding: Theme.spaceXl * 2

                    GlyphIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: "hub"
                        color: Theme.lineDim
                        size: 40
                    }

                    GlyphText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - Theme.spaceXl
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Select a signal on the map. Arrows move, Enter opens, / searches."
                        role: "small"
                        dim: true
                    }
                }

                // ---- header (group or entry) ----
                Row {
                    width: parent.width
                    spacing: Theme.spaceSm
                    visible: root.entry || root.group

                    NomaiFrame {
                        width: 40
                        height: 40
                        shape: "hex"
                        padding: 0
                        fill: Theme.ink2
                        lineColor: root.entry?.urgency === 2 ? Theme.ember : Theme.line
                        lineOpacity: 0.8

                        Image {
                            id: hdrIcon
                            anchors.centerIn: parent
                            visible: root.iconSrc !== "" && status === Image.Ready
                            source: root.iconSrc
                            width: 20
                            height: 20
                            sourceSize: Qt.size(40, 40)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        GlyphIcon {
                            anchors.centerIn: parent
                            visible: !hdrIcon.visible
                            icon: Icons.getNotifIcon(root.entry?.summary ?? "", root.entry?.urgency === 2)
                            color: Theme.line
                            size: 18
                        }
                    }

                    Column {
                        width: parent.width - 40 - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        GlyphText {
                            text: root.entry?.app ?? root.group?.app ?? ""
                            role: "label"
                            width: parent.width
                        }

                        GlyphText {
                            text: root.entry ? Qt.formatDateTime(new Date(root.entry.ts), "ddd d MMM, HH:mm") + (root.live ? "  ·  still open" : "") : (root.group ? `${root.group.count} signal${root.group.count === 1 ? "" : "s"}  ·  ${root.group.unread} unread  ·  latest ${Fmt.age(new Date(root.group.latest))}` : "")
                            role: "small"
                            dim: true
                            width: parent.width
                        }
                    }
                }

                NomaiDivider {
                    width: parent.width
                    segments: 5
                    visible: root.entry || root.group
                }

                // ---- entry ----
                Column {
                    width: parent.width
                    spacing: Theme.spaceSm
                    visible: root.entry !== null

                    Row {
                        width: parent.width
                        spacing: Theme.spaceXs

                        GlyphIcon {
                            visible: root.entry?.urgency === 2
                            icon: "release_alert"
                            color: Theme.ember
                            fill: 1
                            size: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        GlyphText {
                            text: root.entry?.summary ?? ""
                            role: "title"
                            width: parent.width - (root.entry?.urgency === 2 ? 20 : 0)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                        }
                    }

                    GlyphText {
                        visible: (root.entry?.body ?? "") !== ""
                        text: root.entry?.body ?? ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        linkColor: Theme.spark
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }

                    NomaiFrame {
                        visible: (root.entry?.image ?? "") !== ""
                        width: parent.width
                        padding: 2
                        chamfer: Theme.chamferSm
                        fill: Theme.ink1
                        lineOpacity: 0.6
                        implicitHeight: img.status === Image.Ready ? Math.min(220, img.implicitHeight * (width - 4) / Math.max(1, img.implicitWidth)) + 4 : 0

                        Image {
                            id: img
                            anchors.fill: parent
                            anchors.margins: 2
                            source: root.entry?.image ?? ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spaceSm
                        topPadding: Theme.spaceXs

                        Repeater {
                            model: root.entry?.actions ?? []

                            HexButton {
                                required property var modelData
                                text: modelData.text || modelData.id
                                icon: root.live ? "bolt" : "open_in_new"
                                padding: Theme.spaceXs + 1
                                maxWidth: 150
                                tooltip: root.live ? "Invoke on the open notification" : "Notification gone: launches the app"
                                onClicked: Services.ShipLog.act(root.entry, modelData.id)
                            }
                        }

                        HexButton {
                            visible: (root.entry?.actions?.length ?? 0) === 0
                            text: root.live ? "Open" : "Launch app"
                            icon: root.live ? "bolt" : "open_in_new"
                            padding: Theme.spaceXs + 1
                            onClicked: Services.ShipLog.act(root.entry, "")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spaceSm
                        topPadding: Theme.spaceSm

                        HexButton {
                            icon: "push_pin"
                            text: root.entry?.pinned ? "Pinned" : "Pin"
                            active: root.entry?.pinned ?? false
                            padding: Theme.spaceXs + 1
                            onClicked: Services.ShipLog.togglePin(root.entry.id)
                        }

                        HexButton {
                            icon: "delete"
                            text: "Delete"
                            danger: true
                            flat: true
                            padding: Theme.spaceXs + 1
                            onClicked: {
                                const id = root.entry.id;
                                root.entry = null;
                                Services.ShipLog.remove(id);
                            }
                        }
                    }
                }

                // ---- group only ----
                Column {
                    width: parent.width
                    spacing: Theme.spaceSm
                    visible: root.entry === null && root.group !== null

                    Repeater {
                        model: (root.group?.entries ?? []).slice(0, 6)

                        Row {
                            required property var modelData
                            width: parent.width
                            spacing: Theme.spaceSm

                            GlyphIcon {
                                icon: modelData.rumor ? "help" : (modelData.read ? "check" : "fiber_manual_record")
                                color: modelData.read ? Theme.lineDim : Theme.line
                                fill: 1
                                size: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            GlyphText {
                                text: modelData.rumor ? "You've heard a rumor..." : modelData.summary
                                role: "small"
                                dim: modelData.read
                                font.italic: !!modelData.rumor
                                width: parent.width - 12 - 40 - parent.spacing * 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            GlyphText {
                                text: Fmt.age(new Date(modelData.ts))
                                role: "label"
                                dim: true
                                width: 40
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    GlyphText {
                        visible: (root.group?.count ?? 0) > 6
                        text: `+${(root.group?.count ?? 6) - 6} more on the map`
                        role: "label"
                        dim: true
                    }

                    Row {
                        spacing: Theme.spaceSm
                        topPadding: Theme.spaceSm

                        HexButton {
                            icon: "done_all"
                            text: "Mark read"
                            padding: Theme.spaceXs + 1
                            enabled: (root.group?.unread ?? 0) > 0
                            onClicked: {
                                for (const e of root.group.entries)
                                    Services.ShipLog.markRead(e.id);
                            }
                        }

                        HexButton {
                            icon: "delete_sweep"
                            text: "Forget app"
                            danger: true
                            flat: true
                            padding: Theme.spaceXs + 1
                            onClicked: {
                                const app = root.group.app;
                                root.group = null;
                                Services.ShipLog.removeGroup(app);
                            }
                        }
                    }
                }
            }
        }
    }
}
