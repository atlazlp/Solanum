//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules
import qs.modules.drawers
import qs.modules.bar

// quantum-moon shell root. Later phases fill the placeholder Loaders below by dropping files
// at the given paths and flipping `active` (each is gated by DevFlags so a dev instance never
// claims exclusive protocols while another shell is running).
ShellRoot {
    id: root

    settings.watchFiles: false

    Drawers {}
    Bars {}
    Shortcuts {}
    IpcRoot {}

    // Touch singletons so their IPC handlers/state exist from startup.
    Component.onCompleted: {
        void Hypr.monitors;
        void Toaster.toasts;
        void Audio.volume;
        void Brightness.monitors;
        void Network.connected;
        void BarVpn.configured;
        void GameMode.enabled;
        void KvmCapture.active;
        void Players.active;
        void Monitors;
        void IdleInhibitor.enabled;
        void NightLight.enabled;
        void GitWatcher.active;
        void Updates.count;
        void Recorder.running;
        void Lock.locked;
        void Screenshot;
        void Notifs.count;
        void ShipLog.entries;
        void QuantumMoon.slug;
        if (Config.utilities.toasts.configLoaded)
            Toaster.toast("Shell started", DevFlags.dev ? "dev mode" : "", "rocket_launch", "info", 0);
    }

    // ---- Placeholders (filled by later phases) ----
    Loader {
        id: backgrounds
        active: true
        source: Qt.resolvedUrl("modules/background/Backgrounds.qml")
    }

    Loader {
        id: qmFadeOverlay
        active: true
        source: Qt.resolvedUrl("modules/drawers/QmFadeOverlay.qml")
    }

    Loader {
        id: areaPicker
        active: true
        source: Qt.resolvedUrl("modules/areapicker/AreaPicker.qml")
    }

    Loader {
        id: notifications
        active: DevFlags.notificationServer
        source: Qt.resolvedUrl("modules/notifications/NotificationServer.qml")
    }

    Loader {
        id: lock
        active: DevFlags.sessionLock
        source: Qt.resolvedUrl("modules/lock/Lock.qml")
    }

    Loader {
        id: idleMonitors
        active: DevFlags.idleMonitors
        source: Qt.resolvedUrl("modules/IdleMonitors.qml")
    }
}
