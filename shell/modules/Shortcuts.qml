import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

// GlobalShortcut (appid "qm") for every name in docs/dev/design-shell.md.
Scope {
    id: root

    property bool launcherInterrupted: false

    function toggleDrawer(name: string): void {
        const v = Visibilities.getForActive();
        if (!v)
            return;
        if (!v[name] && Hypr.focusedHasFullscreen && !Config.general.showOverFullscreen)
            return;
        Visibilities.toggle(name, v);
    }

    component Qm: GlobalShortcut {
        appid: "qm"
    }

    Qm {
        name: "launcher"
        description: "Toggle launcher on Super release when Super was pressed alone"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted)
                root.toggleDrawer("launcher");
            root.launcherInterrupted = false;
        }
    }

    Qm {
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    Qm {
        name: "lock"
        description: "Lock the session"
        onPressed: Lock.lock()
    }

    Qm {
        name: "unlock"
        description: "Unlock the session"
        onPressed: Lock.unlock()
    }

    Qm {
        name: "session"
        description: "Toggle session menu"
        onPressed: root.toggleDrawer("session")
    }

    Qm {
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: root.toggleDrawer("sidebar")
    }

    Qm {
        name: "shipLog"
        description: "Toggle ship log"
        onPressed: root.toggleDrawer("shipLog")
    }

    Qm {
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: root.toggleDrawer("dashboard")
    }

    Qm {
        name: "utilities"
        description: "Toggle utilities"
        onPressed: root.toggleDrawer("utilities")
    }

    Qm {
        name: "quantumMoon"
        description: "Toggle Solanum panel"
        onPressed: root.toggleDrawer("quantumMoon")
    }

    Qm {
        name: "windowPicker"
        description: "Toggle window picker"
        onPressed: root.toggleDrawer("windowPicker")
    }

    Qm {
        name: "clearNotifs"
        description: "Clear notifications"
        onPressed: Notifs.clear()
    }

    Qm {
        name: "showall"
        description: "Toggle launcher, dashboard, osd and utilities"
        onPressed: {
            const v = Visibilities.getForActive();
            if (!v)
                return;
            const any = v.launcher || v.dashboard || v.osd || v.utilities;
            v.launcher = v.dashboard = v.osd = v.utilities = !any;
        }
    }

    Qm {
        name: "refreshDevices"
        description: "Reload keyboard state (caps/num lock, layout)"
        onPressed: Hypr.refreshDevices()
        onReleased: Hypr.refreshDevices()
    }

    Qm {
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: Players.playPause()
    }

    Qm {
        name: "mediaNext"
        description: "Next track"
        onPressed: Players.next()
    }

    Qm {
        name: "mediaPrev"
        description: "Previous track"
        onPressed: Players.previous()
    }

    Qm {
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: Players.stop()
    }

    Qm {
        name: "brightnessUp"
        description: "Increase brightness"
        onPressed: Brightness.increaseBrightness()
    }

    Qm {
        name: "brightnessDown"
        description: "Decrease brightness"
        onPressed: Brightness.decreaseBrightness()
    }

    Qm {
        name: "screenshot"
        description: "Screenshot area"
        onPressed: Screenshot.open(false, false)
    }

    Qm {
        name: "screenshotFreeze"
        description: "Screenshot area (frozen)"
        onPressed: Screenshot.open(true, false)
    }
}
