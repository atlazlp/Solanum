pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// Three gauges: CPU, memory, storage.
Column {
    id: root

    spacing: Theme.spaceSm

    SectionHeader {
        text: "Resources"
    }

    Row {
        spacing: Theme.spaceLg

        Repeater {
            model: [
                { label: "CPU", icon: "memory", value: SystemUsage.cpuPerc, accent: Theme.line, detail: SystemUsage.cpuTemp > 0 ? `${Math.round(SystemUsage.cpuTemp)}°C` : "" },
                { label: "MEM", icon: "memory_alt", value: SystemUsage.memPerc, accent: Theme.spark, detail: SystemUsage.formatKibStr(SystemUsage.memUsed, 1) },
                { label: "DISK", icon: "hard_drive", value: SystemUsage.storagePerc, accent: Theme.ember, detail: SystemUsage.formatKibStr(SystemUsage.storageUsed, 0) }
            ]

            Column {
                id: gauge

                required property var modelData
                spacing: Theme.spaceXs

                Item {
                    width: 64
                    height: 64

                    ProgressArc {
                        anchors.fill: parent
                        value: gauge.modelData.value
                        accent: gauge.modelData.accent
                        thickness: 4
                        Behavior on value { NumberAnimation { duration: Motion.slow; easing.type: Motion.enter } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 0
                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: gauge.modelData.icon
                            size: Theme.sizeSmall + 3
                            color: gauge.modelData.accent
                        }
                        GlyphText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "mono"
                            text: `${Math.round(gauge.modelData.value * 100)}%`
                            color: Theme.text
                        }
                    }
                }

                GlyphText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "label"
                    text: gauge.modelData.label
                    dim: true
                }

                GlyphText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "small"
                    text: gauge.modelData.detail
                    dim: true
                    visible: text !== ""
                }
            }
        }
    }
}
