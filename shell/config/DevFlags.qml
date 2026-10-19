pragma Singleton

import Quickshell

// Development flags. `QM_SHELL_DEV=1 qs -c solanum` runs the shell side by side
// with another shell: nothing exclusive (notification server, session lock, idle
// monitors) is claimed and the bar does not reserve an exclusive zone.
Singleton {
    id: root

    readonly property bool dev: {
        const v = (Quickshell.env("QM_SHELL_DEV") ?? "").toString().trim().toLowerCase();
        return v !== "" && v !== "0" && v !== "false" && v !== "no";
    }

    // Individual gates (all derived from `dev`; later agents may read these instead of `dev`).
    readonly property bool notificationServer: !dev
    readonly property bool sessionLock: !dev
    readonly property bool idleMonitors: !dev
    readonly property bool barExclusive: !dev
}
