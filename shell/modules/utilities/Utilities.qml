pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils

// Utilities card (bottom-right slot): toggles, recorder, night light, screenshots.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property bool dndAvailable: typeof Notifs !== "undefined" && typeof Notifs.toggleDnd === "function"
    readonly property bool dnd: typeof Notifs !== "undefined" ? (Notifs.dnd ?? false) : false
    readonly property int contentWidth: 340

    function reveal(): void {
        reveal.trigger();
    }

    function toggleDnd(): void {
        if (dndAvailable)
            Notifs.toggleDnd();
        else if (typeof Notifs !== "undefined" && "dnd" in Notifs)
            Notifs.dnd = !Notifs.dnd;
    }

    padding: Theme.spaceLg
    chamfer: Theme.chamferLg
    corners: 1 | 2        // top corners: the card sits on the bottom edge
    fill: Theme.ink
    glow: true
    ticks: true

    GlyphReveal {
        id: reveal

        autoTrigger: false
        implicitWidth: root.contentWidth
        implicitHeight: s4.y + s4.implicitHeight

        readonly property int gap: Theme.spaceMd
        readonly property int sectionWidth: root.contentWidth

        // Sections are direct children (hand-placed) so GlyphReveal staggers them.
            // ---- toggles ----
            Row {
                id: s1
                width: reveal.sectionWidth
                spacing: Theme.spaceSm

                Repeater {
                    model: [
                        { icon: "coffee", label: "Idle", tip: "Keep the screen awake", on: IdleInhibitor.enabled, run: () => IdleInhibitor.enabled = !IdleInhibitor.enabled },
                        { icon: root.dnd ? "notifications_off" : "notifications", label: "DND", tip: "Do not disturb", on: root.dnd, run: () => root.toggleDnd() },
                        { icon: "nightlight", label: "Night", tip: NightLight.enabled ? `Night light ${NightLight.temperature} K` : "Night light", on: NightLight.enabled, run: () => NightLight.toggle() },
                        { icon: "sports_esports", label: "Game", tip: "Game mode", on: GameMode.enabled, run: () => GameMode.toggle() }
                    ]

                    Column {
                        id: toggle
                        required property var modelData
                        width: (reveal.sectionWidth - Theme.spaceSm * 3) / 4
                        spacing: Theme.spaceXs

                        HexButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            shape: "hex"
                            icon: toggle.modelData.icon
                            tooltip: toggle.modelData.tip
                            active: toggle.modelData.on
                            glow: active
                            padding: Theme.spaceSm + 2
                            onClicked: toggle.modelData.run()
                        }

                        GlyphText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "label"
                            text: toggle.modelData.label
                            color: toggle.modelData.on ? Theme.line : Theme.textDim
                        }
                    }
                }
            }

            // ---- night light slider ----
            Column {
                id: s2
                width: reveal.sectionWidth
                y: s1.y + s1.implicitHeight + reveal.gap
                spacing: Theme.spaceXs

                Row {
                    width: parent.width
                    SectionHeader { text: "Night light" }
                    Item { width: parent.width - parent.children[0].implicitWidth - kelvin.implicitWidth; height: 1 }
                    GlyphText {
                        id: kelvin
                        role: "mono"
                        text: `${NightLight.temperature} K`
                        color: NightLight.enabled ? Theme.ember : Theme.textDim
                    }
                }

                NomaiSlider {
                    orientation: Qt.Horizontal
                    length: root.contentWidth
                    thickness: 26
                    from: 3000
                    to: 6500
                    step: 100
                    value: NightLight.temperature
                    accent: Theme.ember
                    muted: !NightLight.enabled
                    onMoved: v => NightLight.set(Math.round(v / 100) * 100)
                }
            }

            // ---- recorder ----
            Column {
                id: s3
                width: reveal.sectionWidth
                y: s2.y + s2.implicitHeight + reveal.gap
                spacing: Theme.spaceSm

                Row {
                    width: parent.width
                    SectionHeader { text: "Recorder" }
                    Item { width: parent.width - parent.children[0].implicitWidth - recState.implicitWidth; height: 1 }

                    Row {
                        id: recState
                        spacing: Theme.spaceXs
                        visible: Recorder.running

                        Rectangle {
                            id: dot
                            width: 8
                            height: 8
                            rotation: 45
                            anchors.verticalCenter: parent.verticalCenter
                            color: Recorder.paused ? Theme.warn : Theme.danger
                            opacity: 1
                            SequentialAnimation on opacity {
                                running: Recorder.running && !Recorder.paused
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 600; easing.type: Motion.fade }
                                NumberAnimation { to: 1; duration: 600; easing.type: Motion.fade }
                            }
                        }
                        GlyphText {
                            role: "label"
                            text: Recorder.paused ? "PAUSED" : "REC"
                            color: Recorder.paused ? Theme.warn : Theme.danger
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        GlyphText {
                            role: "mono"
                            text: Fmt.time(Recorder.elapsed)
                            color: Theme.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Mode picker (idle)
                Grid {
                    visible: !Recorder.running
                    columns: 2
                    columnSpacing: Theme.spaceSm
                    rowSpacing: Theme.spaceSm
                    width: parent.width

                    Repeater {
                        model: Recorder.modes

                        HexButton {
                            required property var modelData
                            width: (root.contentWidth - Theme.spaceSm) / 2
                            icon: modelData.icon
                            text: modelData.label
                            maxWidth: width
                            enabled: !Recorder.busy
                            onClicked: Recorder.start(modelData.id)
                        }
                    }
                }

                // Controls (running)
                Row {
                    visible: Recorder.running
                    width: parent.width
                    spacing: Theme.spaceSm

                    GlyphText {
                        role: "small"
                        text: Recorder.file ? Recorder.file.split("/").pop() : ""
                        dim: true
                        width: parent.width - pauseBtn.width - stopBtn.width - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HexButton {
                        id: pauseBtn
                        icon: Recorder.paused ? "play_arrow" : "pause"
                        tooltip: Recorder.paused ? "Resume" : "Pause"
                        active: Recorder.paused
                        onClicked: Recorder.togglePause()
                    }

                    HexButton {
                        id: stopBtn
                        icon: "stop"
                        text: "Stop"
                        danger: true
                        glow: true
                        onClicked: Recorder.stop()
                    }
                }
            }

            // ---- screenshots ----
            Column {
                id: s4
                width: reveal.sectionWidth
                y: s3.y + s3.implicitHeight + reveal.gap
                spacing: Theme.spaceSm

                SectionHeader { text: "Screenshot" }

                Row {
                    width: parent.width
                    spacing: Theme.spaceSm

                    Repeater {
                        model: [
                            { icon: "screenshot_region", label: "Region", tip: "Select an area (live)", run: () => Screenshot.open(false, false) },
                            { icon: "ac_unit", label: "Frozen", tip: "Freeze the screen, then select", run: () => Screenshot.open(true, false) },
                            { icon: "select_window", label: "Window", tip: "Active window", run: () => Screenshot.window() },
                            { icon: "screenshot_monitor", label: "Screen", tip: "Focused monitor", run: () => Screenshot.screen() }
                        ]

                        HexButton {
                            required property var modelData
                            width: (root.contentWidth - Theme.spaceSm * 3) / 4
                            icon: modelData.icon
                            tooltip: modelData.tip
                            onClicked: {
                                root.visibilities?.closeAll?.();
                                Qt.callLater(modelData.run);
                            }
                        }
                    }
                }
            }
    }
}
