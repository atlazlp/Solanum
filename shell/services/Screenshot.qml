pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Screenshot entry points. The area picker (modules/areapicker/AreaPicker.qml) watches `active`
// and reads `freeze` / `clipboardOnly`; `screen()` / `window()` grab directly with grim.
// Files go to ~/Pictures/Screenshots/<timestamp>.png; edit mode hands the file to swappy,
// clipboard mode copies it with wl-copy.
Singleton {
    id: root

    property bool active: false          // picker requested / shown
    property bool freeze: false
    property bool clipboardOnly: false
    property bool closing: false         // picker fading out (input released)
    property bool capturing: false       // overlays hidden so grim sees the real screen

    signal pickerRequested(bool freeze, bool clipboard)

    readonly property string outDir: (Quickshell.env("XDG_PICTURES_DIR") || `${Quickshell.env("HOME")}/Pictures`) + "/Screenshots"

    function newPath(): string {
        return `${outDir}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.png`;
    }

    function open(freeze: bool, clipboard: bool): void {
        if (active && !closing)
            return;
        root.freeze = freeze;
        root.clipboardOnly = clipboard;
        root.closing = false;
        root.capturing = false;
        root.active = true;
        pickerRequested(freeze, clipboard);
    }

    function close(): void {
        closing = true;
        capturing = false;
        closeTimer.restart();
    }

    // Capture a global-coordinate rect. w/h <= 0 -> whole output `output`.
    function capture(x: int, y: int, w: int, h: int, output: string, clipboard: bool): void {
        const file = newPath();
        const geom = w > 0 && h > 0 ? ["-g", `${Math.round(x)},${Math.round(y)} ${Math.round(w)}x${Math.round(h)}`] : (output ? ["-o", output] : []);
        grab.file = file;
        grab.clipboard = clipboard;
        grab.command = ["sh", "-c", `mkdir -p "$1" && shift && grim "$@"`, "qm-grim", outDir, ...geom, file];
        grab.running = true;
    }

    function screen(): void {
        const name = Hypr.focusedMonitor?.name ?? "";
        capture(0, 0, 0, 0, name, false);
    }

    function window(): void {
        const t = Hypr.activeToplevel;
        const o = t?.lastIpcObject;
        if (!o || !o.at || !o.size) {
            Toaster.toast("Screenshot", "No active window", "screenshot_monitor", "warn", 0);
            return;
        }
        capture(o.at[0], o.at[1], o.size[0], o.size[1], "", false);
    }

    Process {
        id: grab

        property string file: ""
        property bool clipboard: false

        onExited: code => {
            if (code !== 0) {
                Toaster.toast("Screenshot failed", "grim exited with " + code, "screenshot_region", "error", 0);
                return;
            }
            const name = file.split("/").pop();
            if (clipboard) {
                Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "$1"`, "qm-clip", file]);
                Toaster.toast("Screenshot copied", name, "content_copy", "success", 0);
            } else {
                Quickshell.execDetached(["swappy", "-f", file]);
                Toaster.toast("Screenshot taken", name, "screenshot_region", "success", 0);
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 220
        onTriggered: {
            root.active = false;
            root.closing = false;
        }
    }

    IpcHandler {
        target: "picker"

        function open(): void {
            root.open(false, false);
        }

        function openFreeze(): void {
            root.open(true, false);
        }

        function openClip(): void {
            root.open(false, true);
        }

        function openFreezeClip(): void {
            root.open(true, true);
        }

        function screen(): void {
            root.screen();
        }

        function window(): void {
            root.window();
        }
    }
}
