pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Slot wallpaper assignment: Hyprland monitors sorted by x then y map to `slot-<index>.png`
// (index capped at 2). The centre monitor (index 1 when >= 2 monitors) shows no static wallpaper
// while the mpvpaper video is active (state/last-video.path holds a real path).
Singleton {
    id: root

    readonly property string videoStateFile: `${Paths.state}/last-video.path`

    readonly property string slug: QuantumMoon.slug
    property string videoState: ""
    // Bumped whenever the monitor layout changes so slot bindings re-evaluate.
    property int layoutRev: 0

    FileView {
        path: root.videoStateFile
        watchChanges: true
        printErrors: false

        onLoaded: root.videoState = text().trim()
        onFileChanged: reload()
        onLoadFailed: root.videoState = ""
    }

    Connections {
        target: Hypr.monitors

        function onValuesChanged() {
            root.layoutRev++;
        }
    }

    function sortedMonitors(): var {
        void root.layoutRev;
        const list = [...Hypr.monitors.values];
        list.sort((a, b) => {
            if (a.x !== b.x)
                return a.x - b.x;
            return a.y - b.y;
        });
        return list;
    }

    function slotIndexForScreen(screenName: string): int {
        const list = root.sortedMonitors();
        const idx = list.findIndex(m => m.name === screenName);
        if (idx < 0)
            return 0;
        return Math.min(idx, 2);
    }

    function centerScreenName(): string {
        const list = root.sortedMonitors();
        if (list.length === 0)
            return "";
        const idx = list.length >= 2 ? 1 : 0;
        return list[idx].name;
    }

    function centerUsesVideo(): bool {
        const s = root.videoState;
        if (!s.length)
            return false;
        if (s.startsWith("missing:") || s.startsWith("no-mpvpaper") || s.startsWith("lfs-pointer:")
                || s === "no-monitor" || s.startsWith("mpvpaper-exit:")
                || s.startsWith("no-godot") || s.startsWith("godot-exit:")
                || s.startsWith("missing:godot"))
            return false;
        if (s.startsWith("scene:"))
            return false;
        return true;
    }

    function centerUsesScene(): bool {
        const s = root.videoState;
        return s.startsWith("scene:");
    }

    // Centre monitor is covered by either mpvpaper video or the Godot scene.
    function centerUsesLiveWallpaper(): bool {
        return root.centerUsesVideo() || root.centerUsesScene();
    }

    function slotPathForScreen(screenName: string): string {
        if (!root.slug.length)
            return "";
        const idx = root.slotIndexForScreen(screenName);
        return `${Paths.modes}/${root.slug}/wallpapers/slot-${idx}.png`;
    }

    function shouldShowOnScreen(screenName: string): bool {
        const path = root.slotPathForScreen(screenName);
        if (!path.length)
            return false;
        if (root.centerUsesLiveWallpaper() && screenName === root.centerScreenName())
            return false;
        return true;
    }
}
