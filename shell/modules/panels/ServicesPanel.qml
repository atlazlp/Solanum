pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// Centre panel: local LLM stack (Docker / Ollama / Open WebUI) status and controls.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property int contentWidth: 520
    readonly property int gap: Theme.spaceMd
    readonly property bool busy: Services.busy.length > 0

    function reveal(): void {
        reveal.trigger();
    }

    function relExpiry(iso: string): string {
        if (!iso)
            return "";
        const t = Date.parse(iso);
        if (isNaN(t))
            return "";
        const d = Math.round((t - Date.now()) / 60000);
        if (d <= 0)
            return "expiring";
        if (d < 60)
            return `${d} min`;
        if (d < 60 * 48)
            return `${Math.round(d / 60)} h`;
        return "pinned";
    }

    padding: Theme.spaceLg
    chamfer: Theme.chamferLg
    fill: Theme.ink
    glow: true
    ticks: true

    Component.onCompleted: {
        Services.refs++;
        Services.refresh();
    }
    Component.onDestruction: Services.refs--

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
                    icon: "smart_toy"
                    fill: Services.stackOn ? 1 : 0
                    color: Services.stackOn ? Theme.line : Theme.textDim
                    animate: true
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Services"
                    role: "title"
                }

                StatePip {
                    anchors.verticalCenter: parent.verticalCenter
                    up: Services.stackOn
                    partial: Services.stackPartial
                    unknown: Services.lastRefresh === 0
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "small"
                    dim: true
                    text: Services.lastRefresh === 0 ? "probing" : (Services.stackOn ? "stack on" : (Services.stackPartial ? "partial" : "stack off"))
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceSm

                BusyRing {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.busy
                    label: Services.busy
                }

                HexButton {
                    icon: "refresh"
                    flat: true
                    tooltip: "Refresh status"
                    enabled: !Services.refreshing
                    onClicked: Services.refresh()
                }

                HexButton {
                    icon: "power_settings_new"
                    text: Services.stackOn ? "Stack off" : "Stack on"
                    active: Services.stackOn
                    glow: Services.stackOn
                    danger: Services.stackOn
                    enabled: !root.busy
                    tooltip: Services.stackOn ? "docker compose down + stop ollama" : "start ollama + docker compose up"
                    onClicked: Services.llmToggle()
                }
            }
        }

        // ---- Docker ----
        ServiceCard {
            id: dockerCard
            anchors.top: header.bottom
            anchors.topMargin: root.gap
            icon: "deployed_code"
            title: "Docker"
            up: Services.dockerUp
            unknown: Services.lastRefresh === 0
            status: Services.dockerUp ? `engine ${Services.dockerVersion}` : "unreachable"
            detail: Services.dockerUp ? (Services.webuiContainer ? `${Services.webuiContainer.Names ?? "open-webui"}: ${Services.webuiContainer.Status ?? Services.webuiContainer.State}` : "no open-webui container") : "docker info failed (daemon down or no group access)"
        }

        // ---- Ollama ----
        ServiceCard {
            id: ollamaCard
            anchors.top: dockerCard.bottom
            anchors.topMargin: root.gap
            icon: "memory"
            title: "Ollama"
            up: Services.ollamaUp
            unknown: Services.lastRefresh === 0
            status: Services.ollamaUp ? `v${Services.ollamaVersion}` : "down"
            detail: `system unit ${Services.ollamaSystemUnit}  ·  user unit ${Services.ollamaUserUnit}  ·  ${Services.llm.ollamaUrl.replace(/^https?:\/\//, "")}`

            actions: [
                {
                    icon: "restart_alt",
                    text: "Restart",
                    tip: "llm-control restart-ollama",
                    run: () => Services.restartOllama()
                }
            ]

            Column {
                width: parent.width
                spacing: Theme.spaceXs

                GlyphText {
                    visible: Services.ollamaUp && Services.ollamaModels.length === 0
                    role: "small"
                    dim: true
                    text: "no models loaded"
                }

                Repeater {
                    model: Services.ollamaModels

                    Item {
                        id: modelRow
                        required property var modelData
                        width: parent.width
                        height: 30

                        Column {
                            anchors.left: parent.left
                            anchors.right: unload.left
                            anchors.rightMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            GlyphText {
                                width: parent.width
                                role: "mono"
                                text: modelRow.modelData.name
                            }

                            GlyphText {
                                width: parent.width
                                role: "small"
                                dim: true
                                text: {
                                    const m = modelRow.modelData;
                                    const bits = [];
                                    if (m.params)
                                        bits.push(m.params);
                                    if (m.quant)
                                        bits.push(m.quant);
                                    bits.push(Services.fmtBytes(m.size));
                                    bits.push(`VRAM ${Services.fmtBytes(m.vram)}`);
                                    const e = root.relExpiry(m.expires);
                                    if (e)
                                        bits.push(e);
                                    return bits.join("  ·  ");
                                }
                            }
                        }

                        HexButton {
                            id: unload
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "eject"
                            text: "Unload"
                            padding: Theme.spaceXs
                            enabled: !root.busy
                            tooltip: "keep_alive 0"
                            onClicked: Services.unloadModel(modelRow.modelData.name)
                        }
                    }
                }
            }
        }

        // ---- Open WebUI ----
        ServiceCard {
            id: webuiCard
            anchors.top: ollamaCard.bottom
            anchors.topMargin: root.gap
            icon: "language"
            title: "Open WebUI"
            up: Services.webuiUp
            unknown: Services.lastRefresh === 0
            status: Services.webuiUp ? (Services.webuiRunning ? "running" : `http ${Services.webuiHttp}`) : (Services.webuiContainer ? Services.webuiContainer.State : "down")
            detail: {
                const c = Services.webuiContainer;
                const url = Services.llm.webuiUrl.replace(/^https?:\/\//, "");
                if (c && c.Ports)
                    return `${url}  ·  ${c.Ports}`;
                if (c && c.Image)
                    return `${url}  ·  ${c.Image}`;
                return url;
            }

            actions: [
                {
                    icon: "open_in_new",
                    text: "Open",
                    tip: Services.webuiUp ? "xdg-open" : "start the stack, then open",
                    run: () => Services.openWebui()
                }
            ]
        }

        // ---- footer: error / last refresh ----
        Item {
            id: footer
            anchors.top: webuiCard.bottom
            anchors.topMargin: Services.error ? root.gap : Theme.spaceXs
            width: root.contentWidth
            height: Services.error ? err.implicitHeight : 0

            GlyphText {
                id: err
                width: parent.width
                visible: Services.error.length > 0
                role: "small"
                color: Theme.ember
                wrapMode: Text.Wrap
                text: Services.error
            }
        }
    }

    // ---- building blocks ----
    component StatePip: Rectangle {
        property bool up: false
        property bool partial: false
        property bool unknown: false
        width: 8
        height: 8
        rotation: 45
        color: unknown ? Theme.textDim : (up ? Theme.success : (partial ? Theme.warn : Theme.danger))
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

    component ServiceCard: NomaiFrame {
        id: card

        property string icon: ""
        property string title: ""
        property string status: ""
        property string detail: ""
        property bool up: false
        property bool unknown: false
        property list<var> actions: []
        default property alias body: bodyCol.data

        width: root.contentWidth
        padding: Theme.spaceMd
        chamfer: Theme.chamferMd
        fill: Theme.ink1
        lineOpacity: up ? 0.8 : 0.35
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
                        fill: card.up ? 1 : 0
                        color: card.up ? Theme.line : Theme.textDim
                        animate: true
                    }

                    GlyphText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.title
                        role: "large"
                    }

                    StatePip {
                        anchors.verticalCenter: parent.verticalCenter
                        up: card.up
                        unknown: card.unknown
                    }

                    GlyphText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "small"
                        text: card.status
                        color: card.up ? Theme.text : Theme.textDim
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
                            padding: Theme.spaceXs
                            enabled: !root.busy
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
