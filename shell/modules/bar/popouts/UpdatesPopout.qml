pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// Pending package updates: `pkg  old -> new` in mono, repo / AUR sections, Refresh + Update now.
Column {
    id: root

    property var host: null

    readonly property int contentWidth: 400
    readonly property int maxListHeight: 360

    spacing: Theme.spaceSm
    width: contentWidth

    // Flat rows with header entries so repo / AUR sections render without ListView sections.
    readonly property var rows: {
        const out = [];
        if (Updates.repoPackages.length > 0) {
            out.push({ header: true, label: `Repositories  ${Updates.repoPackages.length}` });
            for (const p of Updates.repoPackages)
                out.push(p);
        }
        if (Updates.aurPackages.length > 0) {
            out.push({ header: true, label: `AUR  ${Updates.aurPackages.length}` });
            for (const p of Updates.aurPackages)
                out.push(p);
        }
        return out;
    }

    function fmtTime(iso: string): string {
        if (!iso)
            return "";
        try {
            return new Date(iso).toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
        } catch (e) {
            return iso;
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spaceSm

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: "system_update_alt"
            color: Updates.count > 0 ? Theme.spark : Theme.textDim
        }

        SectionHeader {
            anchors.verticalCenter: parent.verticalCenter
            text: "Updates"
        }

        Item {
            width: parent.width - x - summary.width - parent.spacing
            height: 1
        }

        GlyphText {
            id: summary
            anchors.verticalCenter: parent.verticalCenter
            role: "small"
            dim: true
            text: Updates.checking ? "checking..." : `${Updates.repoCount} repo / ${Updates.aurCount} AUR`
        }
    }

    GlyphText {
        visible: Updates.lastError.length > 0
        width: parent.width
        role: "small"
        color: Theme.danger
        text: Updates.lastError
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    Item {
        width: parent.width
        height: Math.min(list.contentHeight, root.maxListHeight)
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows

            delegate: UpdateRow {
                required property var modelData
                width: ListView.view.width
                pkg: modelData
            }
        }

        Column {
            anchors.centerIn: parent
            visible: list.count === 0
            spacing: Theme.spaceSm

            GlyphIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "check_circle"
                size: Theme.sizeIcon * 1.5
                color: Theme.success
            }

            GlyphText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Updates.checking ? "Checking for updates..." : "System is up to date"
                dim: true
            }
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spaceSm

        HexButton {
            width: (root.width - Theme.spaceSm) / 2
            icon: "sync"
            text: Updates.checking ? "Checking..." : "Refresh"
            padding: Theme.spaceXs
            enabled: !Updates.checking
            onClicked: Updates.refresh()
        }

        HexButton {
            width: (root.width - Theme.spaceSm) / 2
            icon: "download"
            text: "Update now"
            active: Updates.count > 0
            padding: Theme.spaceXs
            onClicked: {
                Updates.run();
                root.host?.hide();
            }
        }
    }

    GlyphText {
        visible: Updates.lastChecked.length > 0
        width: parent.width
        role: "small"
        dim: true
        horizontalAlignment: Text.AlignHCenter
        text: `checked ${root.fmtTime(Updates.lastChecked)}`
    }

    component UpdateRow: Item {
        id: row

        property var pkg: ({})
        readonly property bool header: !!pkg.header

        height: header ? 26 : 22

        SectionHeader {
            visible: row.header
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            text: row.pkg.label ?? ""
        }

        GlyphText {
            id: name
            visible: !row.header
            anchors.left: parent.left
            anchors.right: versions.left
            anchors.rightMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            role: "mono"
            text: row.pkg.name ?? ""
            color: hover.hovered ? Theme.line : Theme.text
        }

        GlyphText {
            id: versions
            visible: !row.header
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.66)
            role: "mono"
            dim: true
            horizontalAlignment: Text.AlignRight
            text: `${row.pkg.from ?? ""} -> ${row.pkg.to ?? ""}`
        }

        HoverHandler { id: hover }
    }
}
