pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Wayland idle inhibitor on a hidden 0x0 window (manual toggle from the bar / utilities / IPC).
Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property alias enabledSince: props.enabledSince

    onEnabledChanged: {
        if (enabled)
            props.enabledSince = new Date();
    }

    PersistentProperties {
        id: props
        property bool enabled: false
        property date enabledSince
        reloadableId: "idleInhibitor"
    }

    // Hidden carrier window for the inhibitor (1x1, click-through, background layer).
    PanelWindow {
        id: carrier
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "solanum-idle-inhibitor"
        WlrLayershell.layer: WlrLayer.Background
    }

    IdleInhibitor {
        enabled: props.enabled
        window: carrier
    }

    IpcHandler {
        target: "idleInhibitor"

        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }
    }
}
