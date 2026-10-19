pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Game mode: strips Hyprland eye candy (hyprctl --batch keywords), optionally drops the VPN,
// runs scripts/qm-game-mode-resources.sh start|stop (if present) and emits qm:gamemode:<on|off>.
Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property string resourcesScript: `${Paths.home}/.config/hypr/scripts/game-mode-resources.sh`
    property bool _booted: false

    readonly property list<string> keywords: ["animations:enabled 0", "decoration:shadow:enabled 0", "decoration:blur:enabled 0", "general:gaps_in 0", "general:gaps_out 0", "general:border_size 1", "decoration:rounding 0", "general:allow_tearing 1"]

    function setDynamicConfs(): void {
        Quickshell.execDetached(["hyprctl", "--batch", keywords.map(k => `keyword ${k}`).join("; ")]);
    }

    function runResources(action: string): void {
        Quickshell.execDetached(["sh", "-c", `[ -x "$1" ] && exec bash "$1" "$2"; exit 0`, "qm-game-mode", resourcesScript, action]);
    }

    function set(on: bool): void {
        props.enabled = on;
    }

    function toggle(): void {
        props.enabled = !props.enabled;
    }

    function reassert(): void {
        if (!props.enabled)
            return;
        setDynamicConfs();
        runResources("stop");
    }

    onEnabledChanged: {
        if (!_booted)
            return;
        if (enabled) {
            setDynamicConfs();
            runResources("stop");
            if (Config.gameMode.autoVpnOff && BarVpn.connected)
                BarVpn.disconnect();
            if (Config.utilities.toasts.gameModeChanged)
                Toaster.toast("Game mode enabled", "Animations, blur, gaps and shadows off", "gamepad", "info", 0);
        } else {
            Quickshell.execDetached(["hyprctl", "reload"]);
            runResources("start");
            if (Config.utilities.toasts.gameModeChanged)
                Toaster.toast("Game mode disabled", "Hyprland settings restored", "gamepad", "info", 0);
        }
        Hypr.emit("gamemode", enabled ? "on" : "off");
    }

    Component.onCompleted: probe.running = true

    // Initial state: animations disabled => game mode is on (survives shell restarts).
    Process {
        id: probe
        command: ["hyprctl", "getoption", "animations:enabled", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text);
                    if (!root._booted && !props.restored)
                        props.enabled = o.int === 0;
                } catch (e) {}
                root._booted = true;
                root.reassert();
            }
        }
        onExited: root._booted = true
    }

    Timer {
        interval: 90000
        running: props.enabled
        repeat: true
        onTriggered: root.reassert()
    }

    PersistentProperties {
        id: props
        property bool enabled: false
        property bool restored: false
        reloadableId: "gameMode"
        onReloaded: restored = true
    }

    Connections {
        target: Hypr
        function onConfigReloaded(): void {
            root.reassert();
        }
    }

    IpcHandler {
        target: "gameMode"

        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            root.toggle();
        }

        function set(on: bool): void {
            root.set(on);
        }

        function enable(): void {
            const was = props.enabled;
            props.enabled = true;
            if (was)
                root.runResources("stop");
        }

        function disable(): void {
            const was = props.enabled;
            props.enabled = false;
            if (!was)
                root.runResources("start");
        }
    }
}
