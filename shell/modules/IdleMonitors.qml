import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Idle monitors from Config.general.idle.timeouts ([{timeout, idleAction, returnAction?}]),
// inhibited while audio plays (Players or the runtime audio marker), resume grace file honoured
// for suspend actions, optional Quantum Moon instant shuffle before lock / dpms off, logind hooks.
// Loaded by shell.qml when DevFlags.idleMonitors.
Scope {
    id: root

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property var idleConfig: Config.general.idle ?? ({})

    readonly property list<string> audioMarkerPaths: [`${runtimeDir}/quantum-moon-audio-playback.active`, `${runtimeDir}/caelestia-audio-playback.active`]
    readonly property list<string> resumeGracePaths: [`${runtimeDir}/quantum-moon-resume-grace.until`, `${runtimeDir}/caelestia-resume-grace.until`]

    property bool markerPlaybackActive: false
    property bool legacyMarkerPlaybackActive: false
    property real resumeGraceUntil: 0
    property real legacyResumeGraceUntil: 0

    readonly property bool inhibitWhenAudio: idleConfig.inhibitWhenAudio !== false
    readonly property bool audioActive: Players.list.some(p => p.isPlaying) || markerPlaybackActive || legacyMarkerPlaybackActive
    readonly property bool enabled: !(inhibitWhenAudio && audioActive)
    readonly property bool shuffleOnIdle: Config.quantumMoon?.shuffleOnIdle !== false
    readonly property bool lockBeforeSleep: idleConfig.lockBeforeSleep !== false

    // `timeouts` list, or the legacy lockTimeout / suspendTimeout pair.
    readonly property list<var> timeouts: {
        const t = idleConfig.timeouts;
        if (Array.isArray(t) && t.length > 0)
            return t;
        const out = [];
        if ((idleConfig.lockTimeout ?? 0) > 0)
            out.push({ timeout: idleConfig.lockTimeout, idleAction: "lock" });
        if ((idleConfig.suspendTimeout ?? 0) > 0)
            out.push({ timeout: idleConfig.suspendTimeout, idleAction: ["systemctl", "suspend"] });
        return out;
    }

    function withinResumeGrace(): bool {
        const until = Math.max(root.resumeGraceUntil, root.legacyResumeGraceUntil);
        return until > 0 && Math.floor(Date.now() / 1000) < until;
    }

    function actionIsSuspend(action: var): bool {
        if (typeof action === "string")
            return /suspend/i.test(action);
        if (Array.isArray(action))
            return action.some(part => typeof part === "string" && /suspend/i.test(part));
        return false;
    }

    function idleActionNeedsShuffle(action: var): bool {
        if (!root.shuffleOnIdle || !root.enabled || QuantumMoon.planetLocked)
            return false;
        if (action === "lock")
            return true;
        return typeof action === "string" && /dpms\s+off/i.test(action);
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;
        if (root.withinResumeGrace() && root.actionIsSuspend(action)) {
            console.log("IdleMonitors: within resume grace, skipping", JSON.stringify(action));
            return;
        }
        if (root.idleActionNeedsShuffle(action)) {
            QuantumMoon.startInstantThen(() => root.runIdleAction(action));
            return;
        }
        root.runIdleAction(action);
    }

    function runIdleAction(action: var): void {
        if (action === "lock") {
            Lock.lock();
            return;
        }
        if (action === "unlock") {
            Lock.unlock();
            return;
        }
        if (typeof action === "string")
            Hypr.dispatch(action);
        else if (Array.isArray(action))
            Quickshell.execDetached(action);
    }

    function writeResumeGrace(seconds: int): void {
        const until = Math.floor(Date.now() / 1000) + seconds;
        resumeGrace.setText(String(until) + "\n");
        root.resumeGraceUntil = until;
    }

    FileView {
        id: audioMarker

        printErrors: false
        path: root.audioMarkerPaths[0]
        onLoaded: root.markerPlaybackActive = true
        onLoadFailed: root.markerPlaybackActive = false
    }

    FileView {
        id: legacyAudioMarker

        printErrors: false
        path: root.audioMarkerPaths[1]
        onLoaded: root.legacyMarkerPlaybackActive = true
        onLoadFailed: root.legacyMarkerPlaybackActive = false
    }

    FileView {
        id: resumeGrace

        printErrors: false
        path: root.resumeGracePaths[0]
        onLoaded: root.resumeGraceUntil = parseInt(text(), 10) || 0
        onLoadFailed: root.resumeGraceUntil = 0
    }

    FileView {
        id: legacyResumeGrace

        printErrors: false
        path: root.resumeGracePaths[1]
        onLoaded: root.legacyResumeGraceUntil = parseInt(text(), 10) || 0
        onLoadFailed: root.legacyResumeGraceUntil = 0
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (root.inhibitWhenAudio) {
                audioMarker.reload();
                legacyAudioMarker.reload();
            }
            resumeGrace.reload();
            legacyResumeGrace.reload();
        }
    }

    Connections {
        target: Logind

        function onAboutToSleep(): void {
            if (root.lockBeforeSleep)
                Lock.lock();
        }

        function onResumed(): void {
            root.writeResumeGrace(300);
            Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "on"]);
        }

        function onLockRequested(): void {
            Lock.lock();
        }

        function onUnlockRequested(): void {
            Lock.unlock();
        }
    }

    Variants {
        model: root.timeouts

        IdleMonitor {
            required property var modelData

            enabled: root.enabled && !Lock.locked && (modelData.enabled ?? true) && (modelData.timeout ?? 0) > 0
            timeout: modelData.timeout ?? 0
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
