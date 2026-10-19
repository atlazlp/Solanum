pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Keeps the Godot solar wallpaper in sync with Solanum settings.
// Planet changes go through qm-apply → qm-video-restart (host swap without reload).
Singleton {
    id: root

    readonly property string centerMode: String(Config.get("quantumMoon.background.centerMode", "scene"))
    readonly property real sceneSpeed: Number(Config.get("quantumMoon.background.sceneSpeed", 4.0))
    readonly property bool scenePreferred: centerMode === "scene"
    readonly property bool eyeSlug: QuantumMoon.slug === "eye-of-the-universe"
    readonly property bool active: scenePreferred && !eyeSlug && QuantumMoonWallpaper.centerUsesScene()

    property string _lastMode: ""
    property real _lastSpeed: -1
    property bool _ready: false

    function pushSpeed(): void {
        if (!QuantumMoonWallpaper.centerUsesScene())
            return;
        speedProc.command = ["qm-godot-ipc", "speed", String(root.sceneSpeed)];
        speedProc.running = false;
        speedProc.running = true;
    }

    Process {
        id: speedProc
    }

    Process {
        id: syncProc
        command: ["qm-video-sync-from-state"]
    }

    Connections {
        target: Config
        function onReload(): void {
            const mode = root.centerMode;
            const speed = root.sceneSpeed;
            if (!root._ready) {
                root._lastMode = mode;
                root._lastSpeed = speed;
                root._ready = true;
                return;
            }
            if (mode !== root._lastMode) {
                root._lastMode = mode;
                root._lastSpeed = speed;
                syncProc.running = false;
                syncProc.running = true;
                return;
            }
            if (speed !== root._lastSpeed) {
                root._lastSpeed = speed;
                root.pushSpeed();
            }
        }
    }
}
