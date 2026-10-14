import QtQuick
import Quickshell
import qs.config
import qs.services

// Opens the osd drawer on volume/mic/brightness changes and closes it after osd.hideDelay
// (kept open while the pointer is over it). One per screen; only screens in modules.osd react.
QtObject {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels

    readonly property bool enabled: Screens.isEnabled("osd", screen.name) && Config.osd.enabled !== false
    readonly property var monitor: Brightness.getMonitorForScreen(screen)
    property bool armed: false

    function show(): void {
        if (!enabled || !armed || KvmCapture.active)
            return;
        if (visibilities.utilities)
            return;
        visibilities.osd = true;
        timer.restart();
    }

    readonly property Timer timer: Timer {
        interval: Config.osd.hideDelay ?? 2000
        onTriggered: {
            if (root.panels.osd.hovered)
                restart();
            else
                root.visibilities.osd = false;
        }
    }

    // Ignore the initial property settles right after startup.
    readonly property Timer armTimer: Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    readonly property Connections audioConn: Connections {
        target: Audio
        function onVolumeChanged(): void { root.show(); }
        function onMutedChanged(): void { root.show(); }
        function onSourceVolumeChanged(): void { root.show(); }
        function onSourceMutedChanged(): void { root.show(); }
    }

    readonly property Connections brightnessConn: Connections {
        target: root.monitor
        function onBrightnessChanged(): void { root.show(); }
    }
}
