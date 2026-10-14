pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils

// Status glyphs: network, audio (scroll = volume, hover = popout), mic (click = reload), vpn, git watcher,
// updates, game mode, idle inhibit, recording, night light, kvm.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    readonly property var st: Config.bar.status
    interactive: false

    function popout(name: string, item: Item): void {
        const host = root.bar?.popouts;
        if (host && Config.bar.popouts.statusIcons !== false)
            host.show(name, item.mapToItem(null, 0, 0).x, item.width, null, false);
    }

    function leave(name: string): void {
        const host = root.bar?.popouts;
        if (host && host.currentName === name)
            host.scheduleHide();
    }

    Row {
        id: iconRow
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        StatusGlyph {
            name: "network"
            shown: root.st.showNetwork !== false && (!Network.wired || root.st.showWifi !== false || true)
            icon: Network.icon
            onEntered: root.popout("network", this)
            onExited: root.leave("network")
        }

        StatusGlyph {
            name: "audio"
            shown: root.st.showAudio !== false
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            dim: Audio.muted
            onEntered: root.popout("audio", this)
            onExited: root.leave("audio")
            onClicked: Audio.toggleMute()
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume(0);
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume(0);
            }
        }

        StatusGlyph {
            name: "microphone"
            shown: root.st.showMicrophone !== false
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            dim: Audio.sourceMuted
            tooltip: "Click to reload the microphone"
            onClicked: Audio.reloadMicrophone()
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementSourceVolume(0);
                else if (event.angleDelta.y < 0)
                    Audio.decrementSourceVolume(0);
            }
        }

        StatusGlyph {
            name: "vpn"
            shown: root.st.showVpn !== false && BarVpn.configured
            icon: "shield"
            fill: BarVpn.connected ? 1 : 0
            accent: BarVpn.connected ? Theme.success : Theme.textDim
            opacity: BarVpn.busy ? 0.45 : 1
            tooltip: `${BarVpn.displayName}: ${BarVpn.connected ? "connected" : "off"}`
            onClicked: BarVpn.toggle()
        }

        StatusGlyph {
            name: "gitwatcher"
            shown: root.st.showGitWatcher !== false && GitWatcher.configured && GitWatcher.active
            icon: GitWatcher.overdueCount > 0 ? "data_alert" : (GitWatcher.count > 0 ? "data_info_alert" : "check")
            fill: 1
            accent: GitWatcher.overdueCount > 0 ? Theme.ember : Theme.textDim
            badge: GitWatcher.mentionCount
            tooltip: `${GitWatcher.count} PRs`
            onEntered: root.popout("gitwatcher", this)
            onExited: root.leave("gitwatcher")
        }

        StatusGlyph {
            name: "updates"
            shown: root.st.showUpdates !== false && Updates.count > 0
            icon: "system_update_alt"
            accent: Theme.spark
            badge: Updates.count
            tooltip: `${Updates.count} updates`
            onClicked: Visibilities.toggle("updates", root.bar?.visibilities ?? null)
        }

        StatusGlyph {
            name: "gamemode"
            shown: root.st.showGameMode !== false && GameMode.enabled
            icon: "gamepad"
            fill: 1
            accent: Theme.ember
            tooltip: "Game mode on (click to disable)"
            onClicked: GameMode.toggle()
        }

        StatusGlyph {
            name: "idleinhibit"
            shown: root.st.showIdleInhibit !== false && IdleInhibitor.enabled
            icon: "coffee"
            fill: 1
            accent: Theme.spark
            tooltip: "Idle inhibited (click to release)"
            onClicked: IdleInhibitor.enabled = false
        }

        StatusGlyph {
            name: "recording"
            shown: root.st.showRecording !== false && Recorder.running
            icon: Recorder.paused ? "pause_circle" : "screen_record"
            fill: 1
            accent: Theme.danger
            tooltip: Recorder.paused ? "Recording paused" : "Recording"

            SequentialAnimation on opacity {
                running: Recorder.running && !Recorder.paused
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Motion.fade }
                NumberAnimation { to: 1; duration: 700; easing.type: Motion.fade }
            }
        }

        StatusGlyph {
            name: "nightlight"
            shown: root.st.showNightLight !== false && NightLight.enabled
            icon: "nightlight"
            fill: 1
            accent: Theme.ember
            tooltip: `Night light ${NightLight.temperature} K (click to toggle)`
            onClicked: NightLight.toggle()
        }

        StatusGlyph {
            name: "kvm"
            shown: root.st.showKvm !== false && (KvmCapture.daemon || KvmCapture.active)
            icon: KvmCapture.active ? "keyboard_external_input" : "devices"
            fill: KvmCapture.active ? 1 : 0
            accent: KvmCapture.active ? Theme.ember : Theme.textDim
            tooltip: KvmCapture.active ? "KVM: captured" : "KVM daemon"
            onClicked: Visibilities.toggle("kvm", root.bar?.visibilities ?? null)
        }
    }

    component StatusGlyph: Item {
        id: glyph

        required property string name
        property bool shown: true
        property string icon: ""
        property real fill: 0
        property bool dim: false
        property color accent: Theme.text
        property int badge: 0
        property string tooltip: ""
        readonly property alias hovered: hh.hovered

        signal entered()
        signal exited()
        signal clicked()
        signal wheel(var event)

        visible: shown
        width: visible ? Theme.sizeIcon * 1.35 : 0
        height: root.height - Theme.spaceSm * 2
        anchors.verticalCenter: parent.verticalCenter

        GlyphIcon {
            anchors.centerIn: parent
            icon: glyph.icon
            fill: glyph.fill
            animate: true
            color: glyph.dim ? Theme.textDim : (hh.hovered ? Theme.line : glyph.accent)
        }

        Rectangle {
            visible: glyph.badge > 0
            anchors.right: parent.right
            anchors.top: parent.top
            width: 7
            height: 7
            color: Theme.ember
            rotation: 45
        }

        HoverHandler {
            id: hh
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: hovered ? glyph.entered() : glyph.exited()
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: glyph.clicked()
        }

        WheelHandler {
            onWheel: event => glyph.wheel(event)
        }

        NomaiTooltip {
            text: glyph.tooltip
            show: glyph.tooltip !== "" && hh.hovered
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.spaceSm
        }
    }
}
