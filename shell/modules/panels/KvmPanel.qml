pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// Centre panel: lan-mouse daemon, capture state, clipboard sync (uniclip) and peers.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property int contentWidth: 520
    readonly property int gap: Theme.spaceMd
    readonly property bool busy: KvmCapture.busy.length > 0

    function reveal(): void {
        reveal.trigger();
    }

    padding: Theme.spaceLg
    chamfer: Theme.chamferLg
    fill: Theme.ink
    glow: true
    ticks: true

    Component.onCompleted: {
        KvmCapture.refs++;
        KvmCapture.refresh();
    }
    Component.onDestruction: KvmCapture.refs--

    GlyphReveal {
        id: reveal

        autoTrigger: false
        implicitWidth: root.contentWidth
        implicitHeight: footer.y + footer.height

        // ---- header ----
        Item {
            id: header
            width: root.contentWidth
            height: 40

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceSm

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: KvmCapture.active ? "keyboard_external_input" : "devices"
                    fill: KvmCapture.daemon ? 1 : 0
                    color: KvmCapture.active ? Theme.ember : (KvmCapture.daemon ? Theme.line : Theme.textDim)
                    animate: true
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "KVM"
                    role: "title"
                }

                StatePip {
                    anchors.verticalCenter: parent.verticalCenter
                    on: KvmCapture.daemon
                    unknown: !KvmCapture.daemonKnown
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "small"
                    dim: !KvmCapture.active
                    color: KvmCapture.active ? Theme.ember : Theme.textDim
                    text: !KvmCapture.daemonKnown ? "probing" : (KvmCapture.active ? "captured by peer" : (KvmCapture.daemon ? "daemon on" : "daemon off"))
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceSm

                BusyRing {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.busy
                    label: KvmCapture.busy
                }

                HexButton {
                    icon: "refresh"
                    flat: true
                    tooltip: "Refresh status"
                    enabled: !KvmCapture.refreshing
                    onClicked: KvmCapture.refresh()
                }

                HexButton {
                    icon: "undo"
                    text: "Restore hovers"
                    tooltip: "Clear the capture flag (hover strips + bar back)"
                    enabled: KvmCapture.active
                    onClicked: KvmCapture.restoreHovers()
                }

                HexButton {
                    icon: "settings"
                    text: "Settings"
                    tooltip: "lan-mouse GTK settings"
                    onClicked: KvmCapture.openGui()
                }
            }
        }

        // ---- daemon ----
        Card {
            id: daemonCard
            anchors.top: header.bottom
            anchors.topMargin: root.gap
            icon: "mouse"
            title: "lan-mouse"
            on: KvmCapture.daemon
            unknown: !KvmCapture.daemonKnown
            status: !KvmCapture.daemonKnown ? "..." : (KvmCapture.daemon ? "running" : "stopped")
            detail: KvmCapture.launchScript.replace(/^\/home\/[^/]+/, "~")

            actions: [
                {
                    icon: "play_arrow",
                    text: "Start",
                    tip: "lan-mouse-launch start",
                    enabled: !KvmCapture.daemon,
                    run: () => KvmCapture.startDaemon()
                },
                {
                    icon: "stop",
                    text: "Stop",
                    tip: "lan-mouse-launch stop",
                    danger: true,
                    enabled: KvmCapture.daemon,
                    run: () => KvmCapture.stopDaemon()
                }
            ]

            // peers
            GlyphText {
                visible: KvmCapture.peers.length === 0
                role: "small"
                dim: true
                text: `no peers in ${KvmCapture.peersConfig.replace(/^\/home\/[^/]+/, "~")}`
            }

            Repeater {
                model: KvmCapture.peers

                Row {
                    id: peerRow
                    required property var modelData
                    spacing: Theme.spaceSm
                    height: 22

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: {
                            switch (peerRow.modelData.position) {
                            case "left": return "arrow_back";
                            case "right": return "arrow_forward";
                            case "top": return "arrow_upward";
                            case "bottom": return "arrow_downward";
                            default: return "computer";
                            }
                        }
                        size: Theme.sizeIcon - 2
                        color: peerRow.modelData.active ? Theme.line : Theme.textDim
                    }

                    GlyphText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "mono"
                        text: peerRow.modelData.hostname || "(unnamed)"
                    }

                    GlyphText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "small"
                        dim: true
                        text: `${peerRow.modelData.ips.join(", ")}  ·  ${peerRow.modelData.position || "?"}${peerRow.modelData.active ? "  ·  auto" : ""}`
                    }
                }
            }
        }

        // ---- clipboard ----
        Card {
            id: clipCard
            anchors.top: daemonCard.bottom
            anchors.topMargin: root.gap
            icon: "content_paste"
            title: "Clipboard sync"
            on: KvmCapture.clipboard
            unknown: !KvmCapture.daemonKnown
            status: !KvmCapture.daemonKnown ? "..." : (KvmCapture.clipboard ? "uniclip on" : "off")
            detail: KvmCapture.logPath.replace(/^\/home\/[^/]+/, "~")

            actions: [
                {
                    icon: "play_arrow",
                    text: "On",
                    tip: "clipboard-sync start",
                    enabled: !KvmCapture.clipboard,
                    run: () => KvmCapture.startClipboard()
                },
                {
                    icon: "stop",
                    text: "Off",
                    tip: "clipboard-sync stop",
                    danger: true,
                    enabled: KvmCapture.clipboard,
                    run: () => KvmCapture.stopClipboard()
                }
            ]

            NomaiFrame {
                width: parent.width
                padding: Theme.spaceSm
                chamfer: Theme.chamferSm
                fill: Theme.ink0
                lineColor: Theme.lineDim
                implicitHeight: logCol.implicitHeight + padding * 2

                Column {
                    id: logCol
                    width: parent.width
                    spacing: 1

                    GlyphText {
                        visible: KvmCapture.logLines.length === 0
                        role: "small"
                        dim: true
                        text: "log empty"
                    }

                    Repeater {
                        model: KvmCapture.logLines

                        GlyphText {
                            required property string modelData
                            width: parent.width
                            role: "mono"
                            font.pointSize: Theme.sizeSmall
                            text: modelData
                            color: /error/i.test(modelData) ? Theme.ember : Theme.textDim
                        }
                    }
                }
            }
        }

        Item {
            id: footer
            anchors.top: clipCard.bottom
            anchors.topMargin: KvmCapture.error ? root.gap : Theme.spaceXs
            width: root.contentWidth
            height: KvmCapture.error ? err.implicitHeight : 0

            GlyphText {
                id: err
                width: parent.width
                visible: KvmCapture.error.length > 0
                role: "small"
                color: Theme.ember
                wrapMode: Text.Wrap
                text: KvmCapture.error
            }
        }
    }

    // ---- building blocks ----
    component StatePip: Rectangle {
        property bool on: false
        property bool unknown: false
        width: 8
        height: 8
        rotation: 45
        color: unknown ? Theme.textDim : (on ? Theme.success : Theme.danger)
        Behavior on color {
            ColorAnimation {
                duration: Motion.normal
            }
        }
    }

    component BusyRing: Row {
        id: ring
        property string label: ""
        spacing: Theme.spaceSm

        ProgressArc {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            value: 0.3
            startAngle: 0
            sweep: 360
            thickness: 2
            glow: false
            accent: Theme.ember
            track: Theme.alpha(Theme.lineDim, 0.5)

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: Motion.reveal * 2
                loops: Animation.Infinite
                running: ring.visible
            }
        }

        GlyphText {
            anchors.verticalCenter: parent.verticalCenter
            role: "small"
            color: Theme.ember
            text: ring.label
        }
    }

    component Card: NomaiFrame {
        id: card

        property string icon: ""
        property string title: ""
        property string status: ""
        property string detail: ""
        property bool on: false
        property bool unknown: false
        property list<var> actions: []
        default property alias body: bodyCol.data

        width: root.contentWidth
        padding: Theme.spaceMd
        chamfer: Theme.chamferMd
        fill: Theme.ink1
        lineOpacity: on ? 0.8 : 0.35
        implicitHeight: col.implicitHeight + padding * 2

        Column {
            id: col
            width: parent.width
            spacing: Theme.spaceSm

            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceSm

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: card.icon
                        fill: card.on ? 1 : 0
                        color: card.on ? Theme.line : Theme.textDim
                        animate: true
                    }

                    GlyphText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.title
                        role: "large"
                    }

                    StatePip {
                        anchors.verticalCenter: parent.verticalCenter
                        on: card.on
                        unknown: card.unknown
                    }

                    GlyphText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "small"
                        text: card.status
                        color: card.on ? Theme.text : Theme.textDim
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceSm

                    Repeater {
                        model: card.actions

                        HexButton {
                            required property var modelData
                            icon: modelData.icon
                            text: modelData.text
                            tooltip: modelData.tip ?? ""
                            danger: modelData.danger ?? false
                            padding: Theme.spaceXs
                            enabled: !root.busy && (modelData.enabled ?? true)
                            onClicked: modelData.run()
                        }
                    }
                }
            }

            GlyphText {
                width: parent.width
                role: "small"
                dim: true
                text: card.detail
                visible: card.detail.length > 0
            }

            Column {
                id: bodyCol
                width: parent.width
                spacing: Theme.spaceXs
            }
        }
    }
}
