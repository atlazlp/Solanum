pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// STUB (Phase 2 step 8 replaces this with the area picker): screenshot entry points.
Singleton {
    id: root

    signal pickerRequested(bool freeze, bool clipboard)

    function open(freeze: bool, clipboard: bool): void {
        console.log("Screenshot: stub picker", freeze, clipboard);
        pickerRequested(freeze, clipboard);
        Toaster.toast("Screenshot", "Area picker not implemented yet", "screenshot_region", "warn", 0);
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
            console.log("Screenshot: stub screen()");
        }

        function window(): void {
            console.log("Screenshot: stub window()");
        }
    }
}
