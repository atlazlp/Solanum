pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// STUB (Phase 2 step 6 replaces this with the full state machine): current planet from state/current.json.
Singleton {
    id: root

    property string slug: ""
    property string displayName: ""
    property bool locked: false
    readonly property string logoPath: slug ? `${Paths.modes}/${slug}/logo.png` : ""

    FileView {
        path: Paths.currentMode
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.slug = String(d.slug ?? "");
                root.displayName = String(d.displayName ?? root.slug);
            } catch (e) {
                console.warn("QuantumMoon: invalid current.json:", e);
            }
        }
        onFileChanged: reload()
        onLoadFailed: err => {}
    }

    FileView {
        path: `${Paths.state}/state.json`
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root.locked = !!JSON.parse(text()).planetLocked;
            } catch (e) {}
        }
        onFileChanged: reload()
        onLoadFailed: err => {}
    }

    IpcHandler {
        target: "qm"

        function current(): string {
            return root.slug;
        }

        function isLocked(): bool {
            return root.locked;
        }

        function random(): void {
            Quickshell.execDetached([`${Paths.qmRoot}/scripts/qm-random`]);
        }

        function instant(): void {
            Quickshell.execDetached([`${Paths.qmRoot}/scripts/qm-random`, "--instant"]);
        }

        function apply(slug: string): void {
            Quickshell.execDetached([`${Paths.qmRoot}/scripts/qm-apply`, slug]);
        }

        function lock(): void {
            console.log("QuantumMoon: stub lock()");
        }

        function unlock(): void {
            console.log("QuantumMoon: stub unlock()");
        }
    }
}
