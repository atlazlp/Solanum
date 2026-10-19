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
            host.show(name, item.mapToItem(null, 0, 0).y, item.height, null, false);
    }

    function leave(name: string): void {
        const host = root.bar?.popouts;
        if (host && host.currentName === name)
            host.scheduleHide();
    }

    padding: Theme.spaceSm

    Column {
        id: iconRow
        spacing: Theme.spaceSm
        anchors.horizontalCenter: parent.horizontalCenter

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
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted || Audio.volume <= 0)
            dim: Audio.muted || Audio.volume <= 0
            accent: Audio.muted || Audio.volume <= 0 ? Theme.textDim : Theme.text
            tooltip: Audio.muted || Audio.volume <= 0 ? "Muted" : "Volume"
            // No hover popout — right-edge VolumeStrip is the mixer UI.
            onClicked: Audio.toggleMute()
            onRightClicked: Visibilities.toggle("audioMixer", root.bar?.visibilities ?? null)
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
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted || Audio.sourceVolume <= 0)
            dim: Audio.sourceMuted || Audio.sourceVolume <= 0
            accent: Audio.sourceMuted || Audio.sourceVolume <= 0 ? Theme.textDim : Theme.text
            tooltip: Audio.sourceMuted || Audio.sourceVolume <= 0 ? "Muted" : "Microphone"
            onClicked: Audio.toggleSourceMute()
            onRightClicked: Audio.reloadMicrophone()
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
            name: "gamemode"
            shown: root.st.showGameMode !== false
            icon: "sports_esports"
            fill: GameMode.enabled ? 1 : 0
            accent: GameMode.enabled ? Theme.ember : Theme.textDim
            tooltip: GameMode.enabled ? "Game mode on (click to disable)" : "Game mode off (click to enable)"
            onClicked: GameMode.toggle()
        }

        StatusGlyph {
            name: "updates"
            shown: root.st.showUpdates !== false && Updates.count > 0
            icon: "system_update_alt"
            accent: Theme.spark
            badge: Updates.count
            tooltip: `${Updates.count} updates`
            onEntered: root.popout("updates", this)
            onExited: root.leave("updates")
            onClicked: {
                root.bar?.popouts?.hide();
                Visibilities.toggle("updates", root.bar?.visibilities ?? null);
            }
        }

        StatusGlyph {
            name: "settings"
            shown: root.st.showSettings !== false
            icon: "settings"
            accent: Theme.spark
            tooltip: "Solanum config"
            onClicked: {
                root.bar?.popouts?.hide();
                Visibilities.toggle("settings", root.bar?.visibilities ?? null);
            }
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
            onRightClicked: Visibilities.toggle("kvm", root.bar?.visibilities ?? null)
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
        signal rightClicked()
        signal wheel(var event)

        visible: shown
        width: Theme.sizeIcon * 1.05
        height: visible ? Theme.sizeIcon * 1.2 : 0
        implicitWidth: width
        implicitHeight: height

        GlyphIcon {
            anchors.centerIn: parent
            icon: glyph.icon
            size: Theme.sizeIcon * 0.88
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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: (point, button) => button === Qt.RightButton ? glyph.rightClicked() : glyph.clicked()
        }

        WheelHandler {
            onWheel: event => glyph.wheel(event)
        }

        NomaiTooltip {
            text: glyph.tooltip
            show: glyph.tooltip !== "" && hh.hovered
            place: "right"
            gap: Theme.spaceSm
        }
    }
}
