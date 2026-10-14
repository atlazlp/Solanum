pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services

// Toast stack (bottom-right of the main screen).
Column {
    id: root

    required property ShellScreen screen
    readonly property bool enabled: screen.name === Screens.mainName
    readonly property int count: enabled ? Toaster.toasts.length : 0

    spacing: Theme.spaceSm
    visible: count > 0
    z: Theme.zToast

    Repeater {
        model: root.enabled ? Toaster.toasts : []

        NomaiFrame {
            id: card

            required property var modelData
            readonly property color accent: {
                switch (modelData.type) {
                case "success": return Theme.success;
                case "warn": return Theme.warn;
                case "error": return Theme.danger;
                }
                return Theme.line;
            }

            padding: Theme.spaceMd
            chamfer: Theme.chamferMd
            fill: Theme.ink1
            lineColor: accent
            glow: true
            ticks: true
            width: 320
            implicitHeight: row.implicitHeight + padding * 2

            Row {
                id: row
                width: parent.width
                spacing: Theme.spaceMd

                GlyphIcon {
                    icon: card.modelData.icon
                    color: card.accent
                    fill: 1
                    anchors.top: parent.top
                }

                Column {
                    width: parent.width - Theme.sizeIcon * 1.6 - parent.spacing
                    spacing: 2

                    GlyphText {
                        text: card.modelData.title
                        role: "large"
                        width: parent.width
                    }

                    GlyphText {
                        visible: card.modelData.message !== ""
                        text: card.modelData.message
                        role: "small"
                        dim: true
                        width: parent.width
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                    }
                }
            }

            TapHandler {
                onTapped: Toaster.dismiss(card.modelData.id)
            }

            Timer {
                interval: card.modelData.timeout
                running: true
                onTriggered: Toaster.dismiss(card.modelData.id)
            }
        }
    }
}
