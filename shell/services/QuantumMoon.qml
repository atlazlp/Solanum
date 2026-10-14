pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Quantum Moon planet state machine (verbatim port of the Caelestia patch service):
//  - current planet from state/current.json (`slug`, `displayName`, `logoPath`)
//  - request queue (<= 2 pending) of random picks / explicit slugs
//  - selector wheel spin (500 ms InOutQuint, 46.5 deg per planet, zero index 2, +0.5 deg, eye = 180 deg)
//  - post-spin timer -> 1000 ms InOutQuad fade to black -> `qm-apply <slug>` -> fade back -> drain queue
//  - `startInstantThen(cb)`: `qm-random` without fade (idle monitor before lock)
//  - scout lock (engage/release, marker placement rules) persisted to state/state.json
Singleton {
    id: root

    // ---- current planet (bar binds to these) ----
    property string slug: ""
    property string displayName: ""
    readonly property string logoPath: slug ? `${Paths.modes}/${slug}/logo.png` : ""
    readonly property bool locked: planetLocked

    // ---- transition state ----
    property real overlayOpacity: 0
    property bool active: false
    property bool planetLocked: false
    property string lockedSlug: ""
    property real lockMarkerX: -1
    property real lockMarkerY: -1
    property bool _lockStateHydrated: false
    property bool _applyingLockFromDisk: false
    property bool _lockSlugMissing: false
    property bool _pendingLockMarkerRoll: false
    property string pendingApplySlug: ""
    property var _requestQueue: []
    property string _pickResolvedSlug: ""
    property var _instantDoneCallback: null

    readonly property int queueLength: _requestQueue.length
    readonly property bool busy: _systemBusy()

    readonly property var wheelPlanetSlugs: ["brittle-hollow", "dark-bramble", "giants-deep", "hourglass-twins", "timber-hearth"]
    readonly property int wheelZeroPlanetIndex: 2
    readonly property real wheelDegPerPlanetIndex: 46.5
    readonly property real wheelRotationOffsetDeg: 0.5
    readonly property int wheelSpinDurationMs: 500
    readonly property int wheelSpinLeadMs: root.wheelSpinDurationMs + 24
    readonly property int fadeDurationMs: 1000

    property real wheelRingDisplayDeg: 0.5

    NumberAnimation {
        id: wheelRingSpin

        target: root
        property: "wheelRingDisplayDeg"
        duration: root.wheelSpinDurationMs
        easing.type: Easing.InOutQuint
    }

    readonly property bool wheelRingSpinning: wheelRingSpin.running

    // ---- destination palette (frame line colour drifts toward the next planet's primary while spinning) ----
    property color destinationPrimary: "transparent"
    property real spinBlend: 0
    property var _paletteCache: ({})
    property string _paletteWantedSlug: ""

    NumberAnimation {
        id: spinBlendAnim

        target: root
        property: "spinBlend"
        from: 0
        to: 1
        duration: root.wheelSpinDurationMs
        easing.type: Easing.InOutQuint
    }

    function palettePrimaryFor(slug: string): color {
        const cached = root._paletteCache[slug];
        return cached ? cached : "transparent";
    }

    function _requestDestinationPalette(slug: string): void {
        const cached = root._paletteCache[slug];
        if (cached) {
            root.destinationPrimary = cached;
            return;
        }
        root._paletteWantedSlug = slug;
        const path = `${Paths.modes}/${slug}/palette.json`;
        if (paletteView.path === path)
            paletteView.reload();
        else
            paletteView.path = path;
    }

    function _primaryFromPalette(j: var): string {
        // palette.json mirrors state/scheme.json: { colours: { primary: "rrggbb", ... } }
        const roots = [j?.colours, j?.colors, j?.palette, j];
        for (const r of roots) {
            if (r && typeof r === "object") {
                for (const k of ["primary", "m3primary", "accent"]) {
                    const v = r[k];
                    if (typeof v === "string" && v.length)
                        return v.startsWith("#") ? v : "#" + v;
                }
            }
        }
        return "";
    }

    FileView {
        id: paletteView

        printErrors: false

        onLoaded: {
            const slug = root._paletteWantedSlug;
            if (!slug.length)
                return;
            try {
                const hex = root._primaryFromPalette(JSON.parse(text()));
                if (hex.length) {
                    const next = Object.assign({}, root._paletteCache);
                    next[slug] = hex;
                    root._paletteCache = next;
                    if (slug === root.pendingApplySlug)
                        root.destinationPrimary = hex;
                }
            } catch (e) {
                console.warn("QuantumMoon: invalid palette.json for", slug, e);
            }
        }
        onLoadFailed: err => {}
    }

    // ---- scout lock geometry ----
    readonly property string lockStateFile: `${Paths.state}/state.json`

    readonly property real lockMarkerBarHeight: 40
    readonly property real lockMarkerBarWidth: lockMarkerBarHeight * 16 / 9
    readonly property real lockMarkerThumbSize: 30
    readonly property real lockMarkerSize: 6
    readonly property real lockMarkerThumbClearancePad: 0.5

    function isLockMarkerInsideBarBounds(x: real, y: real, barWidth: real, barHeight: real): bool {
        if (x < 0 || y < 0)
            return false;
        if (x + root.lockMarkerSize > barWidth + 0.5 || y + root.lockMarkerSize > barHeight + 0.5)
            return false;
        return true;
    }

    function lockMarkerOverlapsThumb(x: real, y: real, barWidth: real, barHeight: real): bool {
        const cx = barWidth * 0.5;
        const cy = barHeight * 0.5;
        const clearance = root.lockMarkerThumbSize * 0.5 + root.lockMarkerSize * 0.5 + root.lockMarkerThumbClearancePad;
        const s = root.lockMarkerSize;
        return x < cx + clearance && x + s > cx - clearance && y < cy + clearance && y + s > cy - clearance;
    }

    function isLockMarkerPlacementValid(x: real, y: real, barWidth: real, barHeight: real): bool {
        return root.isLockMarkerInsideBarBounds(x, y, barWidth, barHeight)
            && !root.lockMarkerOverlapsThumb(x, y, barWidth, barHeight);
    }

    function randomLockMarkerOffset(barWidth: real, barHeight: real): point {
        const s = root.lockMarkerSize;
        const bw = barWidth - s;
        const bh = barHeight - s;
        if (bw <= 0 || bh <= 0)
            return Qt.point(0, 0);
        const cx = barWidth * 0.5;
        const cy = barHeight * 0.5;
        const clearance = root.lockMarkerThumbSize * 0.5 + root.lockMarkerSize * 0.5 + root.lockMarkerThumbClearancePad;
        const pad = 2;
        const edgeGap = 1;
        const leftMax = cx - clearance - s - edgeGap;
        const rightMin = cx + clearance + edgeGap;
        const vertHalfSpan = Math.min(root.lockMarkerThumbSize * 0.55, bh * 0.42);

        function clampPick(px: real, py: real): point {
            const x = Math.max(0, Math.min(px, bw));
            const y = Math.max(0, Math.min(py, bh));
            if (root.isLockMarkerPlacementValid(x, y, barWidth, barHeight))
                return Qt.point(x, y);
            return Qt.point(-1, -1);
        }

        for (let i = 0; i < 140; i++) {
            const pickLeft = Math.random() < 0.5;
            let x = -1;
            if (pickLeft) {
                if (leftMax > pad) {
                    const span = leftMax - pad;
                    x = leftMax - Math.random() * Math.random() * span;
                }
            } else if (rightMin < bw) {
                const span = bw - rightMin;
                x = rightMin + Math.random() * Math.random() * span;
            }
            if (x < 0)
                continue;
            const jy = (Math.random() * 2 - 1) * vertHalfSpan;
            const y = cy - s * 0.5 + jy;
            const pt = clampPick(x, y);
            if (pt.x >= 0)
                return pt;
        }

        const steps = 11;
        for (let si = 0; si < steps; si++) {
            const t = steps === 1 ? 0.5 : si / (steps - 1);
            const y = cy - s * 0.5 + (t * 2 - 1) * vertHalfSpan;
            if (leftMax > pad) {
                const pt = clampPick(leftMax, y);
                if (pt.x >= 0)
                    return pt;
            }
            if (rightMin < bw) {
                const pt = clampPick(rightMin, y);
                if (pt.x >= 0)
                    return pt;
            }
        }

        for (let y = 0; y <= bh; y += 1) {
            for (let x = 0; x <= bw; x += 1) {
                if (!root.lockMarkerOverlapsThumb(x, y, barWidth, barHeight))
                    return Qt.point(x, y);
            }
        }
        return Qt.point(0, 0);
    }

    function rollLockMarker(barWidth: real, barHeight: real): void {
        const pt = root.randomLockMarkerOffset(barWidth, barHeight);
        root.lockMarkerX = pt.x;
        root.lockMarkerY = pt.y;
    }

    function engageLock(slug: string, barWidth: real, barHeight: real): void {
        if (!slug.length)
            return;
        root.lockedSlug = slug;
        root.rollLockMarker(barWidth, barHeight);
        root.planetLocked = true;
    }

    function releaseLock(): void {
        root.planetLocked = false;
        root.lockedSlug = "";
        root.lockMarkerX = -1;
        root.lockMarkerY = -1;
    }

    // Lock the planet that is active right now (used by IPC `qm lock`).
    function lockCurrent(): void {
        if (root.planetLocked)
            return;
        if (root.slug.length)
            root.engageLock(root.slug, root.lockMarkerBarWidth, root.lockMarkerBarHeight);
    }

    // ---- wheel ----
    function wheelRotationDegForPlanetIndex(i: int): real {
        if (i < 0)
            return root.wheelRotationOffsetDeg;
        return (i - root.wheelZeroPlanetIndex) * root.wheelDegPerPlanetIndex + root.wheelRotationOffsetDeg;
    }

    function wheelRotationDegForSlug(slug: string): real {
        if (slug === "eye-of-the-universe")
            return 180;
        return root.wheelRotationDegForPlanetIndex(root.wheelPlanetSlugs.indexOf(slug));
    }

    function adoptWheelRingFromSlug(slug: string): void {
        wheelRingSpin.stop();
        root.wheelRingDisplayDeg = root.wheelRotationDegForSlug(slug);
    }

    function syncWheelRingIfIdle(): void {
        if (!root.active && !root.wheelRingSpinning && !postSpinFadeTimer.running)
            root.adoptWheelRingFromSlug(root.slug);
    }

    function _spinWheelRingToSlug(slug: string): void {
        if (!slug.length)
            return;
        root._requestDestinationPalette(slug);
        spinBlendAnim.stop();
        spinBlendAnim.start();
        const from = root.wheelRingDisplayDeg;
        const to = root.wheelRotationDegForSlug(slug);
        if (Math.abs(to - from) < 0.5)
            return;
        wheelRingSpin.stop();
        wheelRingSpin.from = from;
        wheelRingSpin.to = to;
        wheelRingSpin.start();
    }

    // ---- request queue ----
    function _systemBusy(): bool {
        return root.active || fadeOut.running || pickProc.running || postSpinFadeTimer.running;
    }

    function _enqueue(req: var): void {
        if (root.planetLocked)
            return;
        if (!root._systemBusy()) {
            root._startRequest(req);
            return;
        }
        if (root._requestQueue.length >= 2)
            return;
        const next = root._requestQueue.slice();
        next.push(req);
        root._requestQueue = next;
    }

    function _dequeue(): var {
        if (!root._requestQueue.length)
            return null;
        const first = root._requestQueue[0];
        root._requestQueue = root._requestQueue.slice(1);
        return first;
    }

    function _drainQueueAfterIdle(): void {
        if (root._systemBusy())
            return;
        const next = root._dequeue();
        if (next)
            root._startRequest(next);
    }

    function _startRequest(req: var): void {
        if (root.planetLocked)
            return;
        if (req.random)
            root._beginRandomPick();
        else if (req.slug && req.slug.length)
            root._beginSlugTransition(req.slug);
    }

    function _beginSlugTransition(slug: string): void {
        if (root.planetLocked)
            return;
        root.pendingApplySlug = slug;
        root._spinWheelRingToSlug(slug);
        postSpinFadeTimer.restart();
    }

    function _beginRandomPick(): void {
        root._pickResolvedSlug = "";
        pickProc.command = ["python3", `${Paths.qmRoot}/scripts/qm-random-walk.py`, "pick"];
        pickProc.running = true;
    }

    function _onPickProcExited(exitCode: int): void {
        const slug = root._pickResolvedSlug.length ? root._pickResolvedSlug : pickStdout.text.trim();
        root._pickResolvedSlug = "";
        if (exitCode !== 0 || !slug.length) {
            root._drainQueueAfterIdle();
            return;
        }
        if (root.planetLocked) {
            root._drainQueueAfterIdle();
            return;
        }
        root._beginSlugTransition(slug);
    }

    // ---- public API ----
    function start(): void {
        if (root.planetLocked)
            return;
        root._enqueue({
            random: true,
            slug: ""
        });
    }

    function startInstant(): void {
        root.startInstantThen(null);
    }

    function startInstantThen(callback: var): void {
        if (root.planetLocked) {
            if (callback)
                callback();
            return;
        }
        if (callback) {
            if (root._instantDoneCallback) {
                const prev = root._instantDoneCallback;
                root._instantDoneCallback = function () {
                    prev();
                    callback();
                };
            } else {
                root._instantDoneCallback = callback;
            }
        }
        if (instantProc.running)
            return;
        instantProc.command = ["bash", `${Paths.qmRoot}/scripts/qm-random`];
        instantProc.running = true;
    }

    function _finishInstantShuffle(): void {
        const cb = root._instantDoneCallback;
        root._instantDoneCallback = null;
        if (cb)
            cb();
    }

    function applyPlanetSlug(slug: string): void {
        if (root.planetLocked)
            return;
        if (!slug.length)
            return;
        root._enqueue({
            random: false,
            slug: slug
        });
    }

    // ---- processes ----
    Process {
        id: proc

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("QuantumMoon: apply exited with", exitCode);
            fadeIn.start();
        }
    }

    Process {
        id: instantProc

        onExited: root._finishInstantShuffle()
    }

    Process {
        id: pickProc

        stdout: StdioCollector {
            id: pickStdout

            onStreamFinished: {
                root._pickResolvedSlug = text.trim();
            }
        }

        onExited: function (exitCode, exitStatus) {
            pickExitDefer.exitCode = exitCode;
            pickExitDefer.start();
        }
    }

    Timer {
        id: pickExitDefer

        interval: 0
        repeat: false
        property int exitCode: 0

        onTriggered: root._onPickProcExited(exitCode)
    }

    Timer {
        id: postSpinFadeTimer

        interval: root.wheelSpinLeadMs
        repeat: false

        onTriggered: {
            root.active = true;
            fadeOut.start();
        }
    }

    NumberAnimation {
        id: fadeOut

        target: root
        property: "overlayOpacity"
        from: 0
        to: 1
        duration: root.fadeDurationMs
        easing.type: Easing.InOutQuad
        onFinished: {
            // Screen is fully black here: reset the frame tint so it does not snap later.
            spinBlendAnim.stop();
            root.spinBlend = 0;
            const slug = root.pendingApplySlug;
            root.pendingApplySlug = "";
            if (slug.length)
                proc.command = ["bash", `${Paths.qmRoot}/scripts/qm-apply`, slug];
            else
                proc.command = ["bash", `${Paths.qmRoot}/scripts/qm-random`];
            proc.running = true;
        }
    }

    NumberAnimation {
        id: fadeIn

        target: root
        property: "overlayOpacity"
        from: 1
        to: 0
        duration: root.fadeDurationMs
        easing.type: Easing.InOutQuad
        onFinished: {
            root.active = false;
            root._drainQueueAfterIdle();
        }
    }

    // ---- current planet (state/current.json) ----
    FileView {
        path: Paths.currentMode
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = text().trim();
            if (!t.length)
                return; // qm-apply truncates then rewrites: wait for the next change
            try {
                const d = JSON.parse(t);
                root.slug = String(d.slug ?? "");
                root.displayName = String(d.displayName ?? root.slug);
            } catch (e) {
                console.warn("QuantumMoon: invalid current.json:", e);
            }
        }
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.slug = "";
                root.displayName = "";
            }
        }
    }

    onSlugChanged: {
        root.syncWheelRingIfIdle();
        root.syncPersistedLockFromCurrentSlug();
    }

    onActiveChanged: root.syncWheelRingIfIdle()

    function syncPersistedLockFromCurrentSlug(): void {
        if (root._lockSlugMissing && root.slug.length) {
            root.lockedSlug = root.slug;
            root._lockSlugMissing = false;
            if (root._pendingLockMarkerRoll) {
                root.rollLockMarker(root.lockMarkerBarWidth, root.lockMarkerBarHeight);
                root._pendingLockMarkerRoll = false;
            }
            root.persistLockState();
        }
    }

    // ---- lock state (state/state.json) ----
    FileView {
        id: lockStateView

        path: root.lockStateFile
        watchChanges: true
        printErrors: false
        atomicWrites: true

        onLoaded: root.applyLockState(text())
        onFileChanged: reload()
        onLoadFailed: function (err) {
            if (err === FileViewError.FileNotFound)
                root.applyLockState("");
            else
                root._lockStateHydrated = true;
        }
        onSaveFailed: err => console.warn("QuantumMoon: could not write", path, err)
    }

    function applyLockState(data: string): void {
        root._applyingLockFromDisk = true;
        let locked = false;
        let slug = "";
        let mx = -1;
        let my = -1;
        try {
            if (data.length) {
                const j = JSON.parse(data);
                locked = j.planetLocked === true;
                slug = j.lockedSlug || "";
                if (typeof j.lockMarkerX === "number")
                    mx = j.lockMarkerX;
                if (typeof j.lockMarkerY === "number")
                    my = j.lockMarkerY;
            }
        } catch (e) {}
        root.lockedSlug = slug;
        root.lockMarkerX = mx;
        root.lockMarkerY = my;
        root._lockSlugMissing = locked && !slug.length;
        root._pendingLockMarkerRoll = locked && !root.isLockMarkerPlacementValid(mx, my, root.lockMarkerBarWidth, root.lockMarkerBarHeight);
        root.planetLocked = locked;
        root._applyingLockFromDisk = false;
        root._lockStateHydrated = true;
        if (locked && root._pendingLockMarkerRoll && slug.length) {
            root.rollLockMarker(root.lockMarkerBarWidth, root.lockMarkerBarHeight);
            root._pendingLockMarkerRoll = false;
            root.persistLockState();
        }
        root.syncPersistedLockFromCurrentSlug();
    }

    function persistLockState(): void {
        const j = {
            planetLocked: root.planetLocked
        };
        if (root.planetLocked) {
            j.lockedSlug = root.lockedSlug;
            j.lockMarkerX = root.lockMarkerX;
            j.lockMarkerY = root.lockMarkerY;
        }
        // Re-reading our own write is idempotent (same values -> no change signals), so no ignore flag is needed.
        lockStateView.setText(JSON.stringify(j));
    }

    onPlanetLockedChanged: {
        if (root.planetLocked) {
            root._requestQueue = [];
            postSpinFadeTimer.stop();
            wheelRingSpin.stop();
            spinBlendAnim.stop();
            root.spinBlend = 0;
            root.pendingApplySlug = "";
        }
        if (!root._applyingLockFromDisk && root._lockStateHydrated)
            root.persistLockState();
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Paths.state])

    IpcHandler {
        target: "qm"

        function current(): string {
            return root.slug;
        }

        function isLocked(): bool {
            return root.planetLocked;
        }

        function random(): void {
            root.start();
        }

        function instant(): void {
            root.startInstant();
        }

        function apply(slug: string): void {
            root.applyPlanetSlug(slug);
        }

        function lock(): void {
            root.lockCurrent();
        }

        function unlock(): void {
            root.releaseLock();
        }
    }
}
