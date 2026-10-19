import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// WlSessionLock host: one LockSurface per screen, one shared Pam. Mirrors the Lock singleton's
// `locked`; on unlockRequested fades the surfaces for 120 ms and then clears Lock.locked
// (never gated on a long animation). Loaded by shell.qml when DevFlags.sessionLock.
Scope {
    id: root

    readonly property bool unlocking: unlockTimer.running

    WlSessionLock {
        id: sessionLock

        LockSurface {
            pam: sharedPam
            host: root
        }

        onLockedChanged: {
            // Compositor released the lock (or refused it): keep the singleton in sync.
            if (!locked && Lock.locked)
                Lock.finishUnlock();
        }
    }

    Pam {
        id: sharedPam

        secure: sessionLock.secure
    }

    Timer {
        id: unlockTimer

        interval: 120
        onTriggered: Lock.finishUnlock()
    }

    Connections {
        target: Lock

        function onLockedChanged(): void {
            if (Lock.locked) {
                unlockTimer.stop();
                sessionLock.locked = true;
            } else {
                sessionLock.locked = false;
            }
        }

        function onUnlockRequested(): void {
            if (Lock.locked)
                unlockTimer.restart();
        }
    }

    Component.onCompleted: {
        Lock.hostActive = true;
        if (Lock.locked)
            sessionLock.locked = true;
    }

    Component.onDestruction: Lock.hostActive = false
}
