pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Updates drawer (centre): the pending package list at full size, Refresh / Update now, and a
// "Dry run" that shows the raw `checkupdates` output (plus `yay -Qua`) in a mono box.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property int contentWidth: 640
    readonly property int listHeight: 420

    property bool dryRunning: false
    property string dryOutput: ""
    property bool showDry: false

    function reveal(): void {
        reveal.trigger();
    }

    function dryRun(): void {
        if (dryRunning)
            return;
        dryRunning = true;
        showDry = true;
        dryOutput = "";
        dryProc.running = true;
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

    padding: Theme.spaceXl
    chamfer: Theme.chamferLg
    fill: Theme.ink
    glow: true
    ticks: true
    focus: true

    Keys.onEscapePressed: root.visibilities?.closeAll()

    Process {
        id: dryProc
        command: ["sh", "-c", 'echo "# checkupdates"; checkupdates 2>&1; echo; echo "# yay -Qua"; yay -Qua 2>&1; true']
        stdout: StdioCollector {
            onStreamFinished: root.dryOutput = text.trim().length ? text : "(no output: nothing pending)"
        }
        onExited: root.dryRunning = false
    }

    GlyphReveal {
        id: reveal

        autoTrigger: false
        implicitWidth: root.contentWidth
        implicitHeight: col.implicitHeight

        Column {
            id: col
            width: root.contentWidth
            spacing: Theme.spaceMd

            // ---- header ----
            Row {
                width: parent.width
                spacing: Theme.spaceSm

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "system_update_alt"
                    size: Theme.sizeIcon * 1.4
                    color: Updates.count > 0 ? Theme.spark : Theme.textDim
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.sizeIcon * 1.4 - stats.width - parent.spacing * 2

                    GlyphText {
                        text: "System updates"
                        role: "title"
                    }

                    GlyphText {
                        role: "small"
                        dim: true
                        text: Updates.checking ? "checking..." : (Updates.lastChecked ? `last checked ${root.fmtTime(Updates.lastChecked)}` : "not checked yet")
                    }
                }

                Column {
                    id: stats
                    anchors.verticalCenter: parent.verticalCenter

                    GlyphText {
                        anchors.right: parent.right
                        role: "display"
                        font.pointSize: Theme.sizeTitle * 1.6
                        color: Updates.count > 0 ? Theme.spark : Theme.textDim
                        text: Updates.count.toString()
                    }

                    GlyphText {
                        anchors.right: parent.right
                        role: "label"
                        dim: true
                        text: `${Updates.repoCount} repo / ${Updates.aurCount} aur`
                    }
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

            NomaiDivider {
                segments: 5
            }

            // ---- list / dry run ----
            NomaiFrame {
                width: parent.width
                padding: Theme.spaceMd
                chamfer: Theme.chamferMd
                fill: Theme.ink0
                lineOpacity: 0.5
                ticks: true

                Item {
                    width: parent.width
                    implicitWidth: parent.width
                    implicitHeight: root.listHeight
                    height: root.listHeight
                    clip: true

                    ListView {
                        id: list
                        anchors.fill: parent
                        visible: !root.showDry
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.rows

                        delegate: Item {
                            id: row

                            required property var modelData
                            readonly property bool header: !!modelData.header

                            width: ListView.view.width
                            height: header ? 30 : 26

                            SectionHeader {
                                visible: row.header
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                text: row.modelData.label ?? ""
                            }

                            Rectangle {
                                visible: !row.header && rowHover.hovered
                                anchors.fill: parent
                                color: Theme.ink2
                            }

                            GlyphText {
                                id: pkgName
                                visible: !row.header
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spaceSm
                                anchors.right: pkgVersions.left
                                anchors.rightMargin: Theme.spaceMd
                                anchors.verticalCenter: parent.verticalCenter
                                role: "mono"
                                font.pointSize: Theme.sizeLarge
                                text: row.modelData.name ?? ""
                                color: rowHover.hovered ? Theme.line : Theme.text
                            }

                            GlyphText {
                                id: pkgVersions
                                visible: !row.header
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spaceSm
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width * 0.62)
                                role: "mono"
                                font.pointSize: Theme.sizeLarge
                                dim: true
                                horizontalAlignment: Text.AlignRight
                                text: `${row.modelData.from ?? ""} -> ${row.modelData.to ?? ""}`
                            }

                            HoverHandler {
                                id: rowHover
                                enabled: !row.header
                            }
                        }
                    }

                    Flickable {
                        id: dryView
                        anchors.fill: parent
                        visible: root.showDry
                        clip: true
                        contentWidth: width
                        contentHeight: dryText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        GlyphText {
                            id: dryText
                            width: dryView.width
                            role: "mono"
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideNone
                            text: root.dryRunning ? "running checkupdates..." : root.dryOutput
                            color: root.dryRunning ? Theme.textDim : Theme.text
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: !root.showDry && list.count === 0
                        spacing: Theme.spaceSm

                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: "check_circle"
                            size: Theme.sizeIcon * 2
                            color: Theme.success
                        }

                        GlyphText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "large"
                            text: Updates.checking ? "Checking for updates..." : "System is up to date"
                            dim: true
                        }
                    }
                }
            }

            // ---- actions ----
            Row {
                width: parent.width
                spacing: Theme.spaceSm

                HexButton {
                    width: (parent.width - Theme.spaceSm * 2) / 3
                    icon: "sync"
                    text: Updates.checking ? "Checking..." : "Refresh"
                    enabled: !Updates.checking
                    onClicked: Updates.refresh()
                }

                HexButton {
                    width: (parent.width - Theme.spaceSm * 2) / 3
                    icon: root.showDry ? "list" : "science"
                    text: root.showDry ? "Package list" : (root.dryRunning ? "Running..." : "Dry run")
                    active: root.showDry
                    enabled: !root.dryRunning
                    tooltip: "Raw checkupdates / yay -Qua output"
                    onClicked: root.showDry ? root.showDry = false : root.dryRun()
                }

                HexButton {
                    width: (parent.width - Theme.spaceSm * 2) / 3
                    icon: "download"
                    text: "Update now"
                    active: Updates.count > 0
                    glow: Updates.count > 0
                    onClicked: {
                        Updates.run();
                        root.visibilities?.closeAll();
                    }
                }
            }
        }
    }
}
