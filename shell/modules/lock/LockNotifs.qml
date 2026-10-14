import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services

// Pending notifications (Notifs.list, guarded) as compact rows; "lock.hideNotifs" hides the bodies.
NomaiFrame {
    id: root

    readonly property bool hide: Config.get("lock.hideNotifs", false) === true
    readonly property list<var> items: {
        const list = Notifs.list ?? [];
        const out = [];
        for (const n of list)
            if (n && !n.closed)
                out.push(n);
        return out;
    }

    padding: Theme.spaceMd
    fill: Theme.alpha(Theme.ink2, 0.9)
    lineOpacity: 0.5
    corners: 4

    Column {
        anchors.fill: parent
        spacing: Theme.spaceSm

        SectionHeader {
            id: header
            text: root.items.length > 0 ? `${root.items.length} signal${root.items.length === 1 ? "" : "s"}` : "Signals"
        }

        Item {
            width: parent.width
            height: parent.height - header.height - parent.spacing

            Column {
                anchors.centerIn: parent
                spacing: Theme.spaceSm
                visible: root.items.length === 0 || root.hide

                GlyphIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: root.hide ? "lock" : "notifications_off"
                    size: 28
                    color: Theme.lineDim
                }

                GlyphText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "small"
                    dim: true
                    text: root.hide ? "Unlock to read signals" : "No signals"
                }
            }

            ListView {
                anchors.fill: parent
                visible: root.items.length > 0 && !root.hide
                clip: true
                spacing: Theme.spaceXs
                model: root.items
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: row

                    required property var modelData

                    width: ListView.view.width
                    height: col.implicitHeight + Theme.spaceSm * 2

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: row.modelData.critical ? Theme.danger : Theme.lineSoft
                    }

                    Column {
                        id: col

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spaceMd
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        GlyphText {
                            width: parent.width
                            role: "label"
                            dim: true
                            text: `${row.modelData.appName || "app"} · ${row.modelData.timeStr || ""}`
                        }

                        GlyphText {
                            width: parent.width
                            role: "small"
                            text: row.modelData.summary || ""
                        }

                        GlyphText {
                            width: parent.width
                            role: "small"
                            dim: true
                            text: row.modelData.body || ""
                            visible: text !== ""
                        }
                    }
                }
            }
        }
    }
}
