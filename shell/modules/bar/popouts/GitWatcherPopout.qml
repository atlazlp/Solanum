pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// Azure DevOps PR feed: Feed / Archived tabs, cards with age or stall time, hover actions
// (open, mute, dismiss / restore), Refresh + Config footer and the daemon state line.
Column {
    id: root

    property var host: null
    property int tab: 0

    readonly property int contentWidth: 400
    readonly property int listHeight: 380

    spacing: Theme.spaceSm
    width: contentWidth

    function fmtAge(minutes: int): string {
        if (!minutes || minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes}m`;
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        if (h >= 48)
            return `${Math.floor(h / 24)}d`;
        return m > 0 ? `${h}h${m}m` : `${h}h`;
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

    function openUrl(url: string): void {
        if (url && url.length)
            Qt.openUrlExternally(url);
    }

    readonly property string daemonLabel: {
        switch (GitWatcher.daemonState) {
        case "systemd": return "daemon: systemd unit";
        case "legacy": return "legacy daemon running (caelestia profile)";
        case "external": return "daemon: running";
        case "self": return "daemon: spawned by shell";
        case "stopped": return "daemon stopped";
        case "unconfigured": return "not configured";
        default: return "checking daemon...";
        }
    }

    // ---- header ----
    Row {
        width: parent.width
        spacing: Theme.spaceSm

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: GitWatcher.filteredOverdueCount > 0 ? "data_alert" : (GitWatcher.unmutedFeedCount > 0 ? "data_info_alert" : "check")
            fill: 1
            animate: true
            color: GitWatcher.filteredOverdueCount > 0 ? Theme.ember : Theme.line
        }

        SectionHeader {
            anchors.verticalCenter: parent.verticalCenter
            text: "Azure DevOps"
        }

        Item {
            width: parent.width - x - spinner.width - attn.width - parent.spacing * 2
            height: 1
        }

        GlyphIcon {
            id: spinner
            anchors.verticalCenter: parent.verticalCenter
            visible: GitWatcher.loading
            width: visible ? implicitWidth : 0
            icon: "sync"
            color: Theme.textDim

            RotationAnimation on rotation {
                running: GitWatcher.loading
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }

        NomaiFrame {
            id: attn
            anchors.verticalCenter: parent.verticalCenter
            visible: GitWatcher.attentionCount > 0
            width: visible ? implicitWidth : 0
            shape: "hex"
            padding: Theme.spaceXs
            fill: GitWatcher.filteredOverdueCount > 0 ? Theme.alpha(Theme.ember, 0.25) : Theme.alpha(Theme.line, 0.16)
            lineColor: GitWatcher.filteredOverdueCount > 0 ? Theme.ember : Theme.line
            glow: GitWatcher.filteredOverdueCount > 0

            GlyphText {
                text: GitWatcher.attentionCount.toString()
                role: "small"
                leftPadding: Theme.spaceXs
                rightPadding: Theme.spaceXs
            }
        }
    }

    // ---- error banner ----
    GlyphText {
        visible: GitWatcher.lastError.length > 0
        width: parent.width
        text: GitWatcher.lastError
        role: "small"
        color: Theme.danger
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    // ---- tabs ----
    Row {
        width: parent.width
        spacing: Theme.spaceSm

        Repeater {
            model: [
                { key: 0, label: "Feed", icon: "inbox" },
                { key: 1, label: "Archived", icon: "archive" }
            ]

            HexButton {
                required property var modelData
                readonly property int n: modelData.key === 0 ? GitWatcher.mainFeedItems.length : GitWatcher.archiveFeedItems.length

                width: (root.width - Theme.spaceSm) / 2
                icon: modelData.icon
                text: n > 0 ? `${modelData.label}  ${n}` : modelData.label
                active: root.tab === modelData.key
                padding: Theme.spaceXs
                onClicked: root.tab = modelData.key
            }
        }
    }

    // ---- lists ----
    Item {
        width: parent.width
        height: root.listHeight
        clip: true

        ListView {
            id: feedList
            anchors.fill: parent
            visible: root.tab === 0
            model: GitWatcher.mainFeedItems
            delegate: feedDelegate
            spacing: Theme.spaceSm
            clip: true
            boundsBehavior: Flickable.StopAtBounds
        }

        ListView {
            id: archiveList
            anchors.fill: parent
            visible: root.tab === 1
            model: GitWatcher.archiveFeedItems
            delegate: archiveDelegate
            spacing: Theme.spaceSm
            clip: true
            boundsBehavior: Flickable.StopAtBounds
        }

        Column {
            anchors.centerIn: parent
            visible: (root.tab === 0 ? feedList.count : archiveList.count) === 0
            spacing: Theme.spaceSm

            GlyphIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.tab === 0 ? "check_circle" : "inventory_2"
                size: Theme.sizeIcon * 1.6
                color: Theme.textDim
            }

            GlyphText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.tab === 0 ? "Nothing to review" : "No archived items"
                dim: true
            }
        }
    }

    // ---- footer ----
    Row {
        width: parent.width
        spacing: Theme.spaceSm

        HexButton {
            width: (root.width - Theme.spaceSm) / 2
            icon: "sync"
            text: GitWatcher.loading ? "Refreshing..." : "Refresh"
            padding: Theme.spaceXs
            enabled: !GitWatcher.loading && GitWatcher.daemonAlive
            onClicked: GitWatcher.refresh()
        }

        HexButton {
            width: (root.width - Theme.spaceSm) / 2
            icon: "settings"
            text: "Config"
            padding: Theme.spaceXs
            onClicked: {
                GitWatcher.openConfig();
                root.host?.hide();
            }
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spaceSm

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            rotation: 45
            color: GitWatcher.daemonAlive ? (GitWatcher.daemonState === "legacy" ? Theme.warn : Theme.success) : Theme.danger
        }

        GlyphText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.daemonLabel
            role: "small"
            dim: true
        }

        Item {
            width: parent.width - x - updated.width - parent.spacing
            height: 1
        }

        GlyphText {
            id: updated
            anchors.verticalCenter: parent.verticalCenter
            visible: GitWatcher.lastUpdated.length > 0
            text: visible ? `updated ${root.fmtTime(GitWatcher.lastUpdated)}` : ""
            role: "small"
            dim: true
        }
    }

    // ---- feed card ----
    Component {
        id: feedDelegate

        NomaiFrame {
            id: card

            required property var modelData
            readonly property bool isPr: modelData.itemType === "pr"
            readonly property bool hot: isPr ? (modelData.isOverdue || modelData.hasMentions) : modelData.itemType === "mention"
            readonly property color accent: {
                if (card.isPr && card.modelData.isOverdue)
                    return GitWatcher.overdueColor;
                if ((card.isPr && card.modelData.hasMentions) || card.modelData.itemType === "mention")
                    return GitWatcher.mentionColor;
                return Theme.lineDim;
            }
            readonly property bool showActions: hover.hovered
            readonly property bool usesPosted: GitWatcher.discordFirst && (modelData.postedMinutes ?? -1) >= 0
            readonly property int displayMin: {
                if (usesPosted)
                    return modelData.postedMinutes;
                const stall = modelData.stallMinutes ?? 0;
                return stall > 0 ? stall : (modelData.ageMinutes ?? 0);
            }

            width: ListView.view?.width ?? root.width
            padding: Theme.spaceSm
            chamfer: Theme.chamferSm
            fill: hover.hovered ? Theme.ink2 : (card.hot ? Theme.alpha(card.accent, 0.10) : Theme.ink0)
            lineColor: card.hot ? card.accent : Theme.line
            lineOpacity: hover.hovered ? 1 : (card.hot ? 0.8 : 0.35)
            opacity: modelData.isMuted ? 0.55 : 1

            Behavior on fill {
                ColorAnimation { duration: Motion.fast; easing.type: Motion.fade }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.openUrl(card.modelData.url)
            }

            Column {
                width: parent.width
                spacing: Theme.spaceXs

                // PR row
                Row {
                    visible: card.isPr
                    width: parent.width
                    spacing: Theme.spaceSm

                    GlyphText {
                        id: chip
                        anchors.verticalCenter: parent.verticalCenter
                        role: "label"
                        color: card.hot ? card.accent : Theme.textDim
                        text: card.modelData.isOverdue ? "stalled"
                            : card.modelData.hasMentions ? "mention"
                            : card.modelData.hasUnreadComments ? "comment"
                            : card.modelData.isOwned ? "mine" : "pr"
                    }

                    GlyphText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - chip.width - age.width - parent.spacing * 2
                        text: card.modelData.title ?? ""
                        font.weight: card.modelData.isOwned ? Font.DemiBold : Font.Normal
                    }

                    GlyphText {
                        id: age
                        anchors.verticalCenter: parent.verticalCenter
                        role: "small"
                        color: card.modelData.isOverdue ? GitWatcher.overdueColor : Theme.textDim
                        text: card.usesPosted ? `posted ${root.fmtAge(card.displayMin)}`
                            : (card.modelData.isOverdue ? `stalled ${root.fmtAge(card.displayMin)}` : root.fmtAge(card.displayMin))
                    }
                }

                Row {
                    visible: card.isPr
                    width: parent.width
                    spacing: Theme.spaceSm

                    GlyphText {
                        id: repoLbl
                        width: parent.width - branch.width - parent.spacing
                        role: "small"
                        dim: true
                        text: (card.modelData.project !== "" ? `${card.modelData.project} / ` : "") + (card.modelData.repo ?? "")
                    }

                    GlyphText {
                        id: branch
                        role: "mono"
                        font.pointSize: Theme.sizeSmall
                        dim: true
                        text: `-> ${card.modelData.targetBranch}`
                        width: Math.min(implicitWidth, 120)
                    }
                }

                // Comment / mention row
                Row {
                    visible: !card.isPr
                    width: parent.width
                    spacing: Theme.spaceSm

                    GlyphIcon {
                        id: cmIcon
                        icon: card.modelData.itemType === "mention" ? "alternate_email" : "chat"
                        color: card.modelData.itemType === "mention" ? GitWatcher.mentionColor : Theme.textDim
                        size: Theme.sizeIcon * 0.9
                    }

                    Column {
                        width: parent.width - cmIcon.width - parent.spacing
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: Theme.spaceXs

                            GlyphText {
                                id: author
                                role: "small"
                                color: Theme.line
                                text: card.modelData.author ?? ""
                                width: Math.min(implicitWidth, 120)
                            }

                            GlyphText {
                                width: parent.width - author.width - parent.spacing
                                role: "small"
                                dim: true
                                text: `- ${card.modelData.title ?? ""}`
                            }
                        }

                        GlyphText {
                            width: parent.width
                            role: "small"
                            text: card.modelData.excerpt ?? ""
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                        }
                    }
                }

                // Action strip (hover)
                Item {
                    width: parent.width
                    height: card.showActions ? actionRow.implicitHeight + Theme.spaceXs : 0
                    clip: true
                    opacity: card.showActions ? 1 : 0

                    Behavior on height {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.enter }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.fade }
                    }

                    Row {
                        id: actionRow
                        anchors.bottom: parent.bottom
                        width: parent.width
                        spacing: Theme.spaceSm

                        HexButton {
                            flat: true
                            icon: "open_in_new"
                            text: "Open"
                            padding: 2
                            onClicked: root.openUrl(card.modelData.url)
                        }

                        Item {
                            width: parent.width - x - muteBtn.width - dismissBtn.width - parent.spacing * 2
                            height: 1
                        }

                        HexButton {
                            id: muteBtn
                            flat: true
                            icon: card.modelData.isMuted ? "notifications_off" : "notifications"
                            text: card.modelData.isMuted ? "Unmute" : "Mute"
                            padding: 2
                            onClicked: card.modelData.isMuted ? GitWatcher.unmute(card.modelData.prId) : GitWatcher.mute(card.modelData.prId)
                        }

                        HexButton {
                            id: dismissBtn
                            flat: true
                            danger: true
                            icon: "archive"
                            text: "Dismiss"
                            padding: 2
                            onClicked: GitWatcher.dismiss(card.modelData.prId)
                        }
                    }
                }
            }
        }
    }

    // ---- archive card ----
    Component {
        id: archiveDelegate

        NomaiFrame {
            id: arch

            required property var modelData
            readonly property bool dismissed: modelData.itemType === "pr_archived"

            width: ListView.view?.width ?? root.width
            padding: Theme.spaceSm
            chamfer: Theme.chamferSm
            fill: ahover.hovered ? Theme.ink2 : Theme.ink0
            lineColor: arch.dismissed ? Theme.warn : Theme.lineDim
            lineOpacity: ahover.hovered ? 1 : 0.4
            opacity: 0.8

            HoverHandler {
                id: ahover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.openUrl(arch.modelData.url)
            }

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                GlyphText {
                    id: archChip
                    anchors.verticalCenter: parent.verticalCenter
                    role: "label"
                    color: arch.dismissed ? Theme.warn : Theme.textDim
                    text: arch.dismissed ? "dismissed" : "merged"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - archChip.width - restore.width - parent.spacing * 2
                    spacing: 1

                    GlyphText {
                        width: parent.width
                        role: "small"
                        text: arch.modelData.title ?? ""
                    }

                    GlyphText {
                        width: parent.width
                        role: "small"
                        dim: true
                        text: (arch.modelData.project !== "" ? `${arch.modelData.project} / ` : "") + (arch.modelData.repo ?? "") + `  ${root.fmtAge(arch.modelData.ageMinutes)}`
                    }
                }

                HexButton {
                    id: restore
                    anchors.verticalCenter: parent.verticalCenter
                    visible: arch.dismissed
                    width: visible ? implicitWidth : 0
                    flat: true
                    icon: "unarchive"
                    padding: 2
                    tooltip: "Restore to feed"
                    onClicked: GitWatcher.undismiss(arch.modelData.prId)
                }
            }
        }
    }
}
