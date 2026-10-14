pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// Performance tab: CPU / GPU / MEM / STORAGE / NET cards with 30-sample sparklines.
GlyphReveal {
    id: root

    readonly property int cardW: 178
    readonly property int gap: Theme.spaceMd

    readonly property list<var> cards: [
        {
            label: "CPU", icon: "memory", accent: Theme.line,
            value: `${Math.round(SystemUsage.cpuPerc * 100)}%`,
            sub: SystemUsage.cpuTemp > 0 ? `${Math.round(SystemUsage.cpuTemp)}°C` : "",
            name: SystemUsage.cpuName,
            history: SystemUsage.cpuHistory, max: 1
        },
        {
            label: "GPU", icon: "developer_board", accent: Theme.spark,
            value: SystemUsage.gpuType === "NONE" ? "n/a" : `${Math.round(SystemUsage.gpuPerc * 100)}%`,
            sub: SystemUsage.gpuTemp > 0 ? `${Math.round(SystemUsage.gpuTemp)}°C` : "",
            name: SystemUsage.gpuName,
            history: SystemUsage.gpuHistory, max: 1
        },
        {
            label: "MEM", icon: "memory_alt", accent: Theme.ember,
            value: `${Math.round(SystemUsage.memPerc * 100)}%`,
            sub: `${SystemUsage.formatKibStr(SystemUsage.memUsed, 1)} / ${SystemUsage.formatKibStr(SystemUsage.memTotal, 0)}`,
            name: "",
            history: SystemUsage.memHistory, max: 1
        },
        {
            label: "STORAGE", icon: "hard_drive", accent: Theme.success,
            value: `${Math.round(SystemUsage.storagePerc * 100)}%`,
            sub: `${SystemUsage.formatKibStr(SystemUsage.storageUsed, 0)} / ${SystemUsage.formatKibStr(SystemUsage.storageTotal, 0)}`,
            name: SystemUsage.disks.map(d => `${d.mount} ${Math.round(d.perc * 100)}%`).join("  "),
            history: [], max: 1
        },
        {
            label: "NET", icon: "swap_vert", accent: Theme.warn,
            value: `↓ ${NetworkUsage.formatRateStr(NetworkUsage.downloadSpeed)}`,
            sub: `↑ ${NetworkUsage.formatRateStr(NetworkUsage.uploadSpeed)}`,
            name: `${NetworkUsage.formatTotalStr(NetworkUsage.downloadTotal)} ↓  ${NetworkUsage.formatTotalStr(NetworkUsage.uploadTotal)} ↑`,
            history: NetworkUsage.downloadHistory, max: 0,
            history2: NetworkUsage.uploadHistory
        }
    ]

    autoTrigger: false
    implicitWidth: cards.length * cardW + (cards.length - 1) * gap
    implicitHeight: 190

    Repeater {
        model: root.cards

        NomaiFrame {
            id: card

            required property var modelData
            required property int index

            x: index * (root.cardW + root.gap)
            width: root.cardW
            height: root.implicitHeight
            padding: Theme.spaceMd
            chamfer: Theme.chamferMd
            fill: Theme.ink1
            lineColor: modelData.accent
            lineOpacity: 0.55
            ticks: true

            Column {
                id: body
                width: card.width - card.padding * 2
                spacing: Theme.spaceXs

                Row {
                    spacing: Theme.spaceSm
                    GlyphIcon {
                        icon: card.modelData.icon
                        size: Theme.sizeSmall + 4
                        color: card.modelData.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    GlyphText {
                        role: "label"
                        text: card.modelData.label
                        color: card.modelData.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                GlyphText {
                    role: "title"
                    text: card.modelData.value
                    color: Theme.text
                    font.pointSize: 18
                }

                GlyphText {
                    role: "mono"
                    text: card.modelData.sub || " "
                    dim: true
                    width: parent.width
                }

                Item {
                    id: chart
                    width: body.width
                    height: 54

                    // Storage has no history: show per-disk bars instead.
                    Column {
                        visible: card.modelData.label === "STORAGE"
                        width: chart.width
                        spacing: 3
                        Repeater {
                            model: card.modelData.label === "STORAGE" ? SystemUsage.disks.slice(0, 4) : []
                            Item {
                                id: diskRow
                                required property var modelData
                                width: chart.width
                                height: 11
                                Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.lineDim, 0.4) }
                                Rectangle {
                                    width: diskRow.width * diskRow.modelData.perc
                                    height: diskRow.height
                                    color: Theme.alpha(card.modelData.accent, 0.5)
                                    Behavior on width { NumberAnimation { duration: Motion.slow } }
                                }
                                GlyphText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 3
                                    role: "label"
                                    font.letterSpacing: 0
                                    font.capitalization: Font.MixedCase
                                    text: `${diskRow.modelData.mount}  ${SystemUsage.formatKibStr(diskRow.modelData.free, 0)} free`
                                    color: Theme.text
                                }
                            }
                        }
                    }

                    Sparkline {
                        visible: card.modelData.label !== "STORAGE"
                        anchors.fill: parent
                        values: card.modelData.history
                        max: card.modelData.label === "NET" ? Math.max(1, ...(card.modelData.history ?? []), ...(card.modelData.history2 ?? [])) : card.modelData.max
                        accent: card.modelData.accent
                    }

                    Sparkline {
                        visible: card.modelData.label === "NET"
                        anchors.fill: parent
                        values: card.modelData.history2 ?? []
                        max: Math.max(1, ...(card.modelData.history ?? []), ...(card.modelData.history2 ?? []))
                        accent: Theme.spark
                        fillArea: false
                    }
                }

                GlyphText {
                    role: "label"
                    font.letterSpacing: 0
                    font.capitalization: Font.MixedCase
                    text: card.modelData.name
                    dim: true
                    width: parent.width
                    visible: text !== ""
                }
            }
        }
    }
}
