pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.config
import qs.services

// One notification as the shell sees it. Wraps a live `Notification` (from the server) or a
// persisted / synthetic record. Owns the expire timer, the popup lifecycle (popup -> leaving ->
// gone) and the image cache (image:// sources vanish with the notification, so they are grabbed
// into ~/.cache/quantum-moon/notifs/<hash>.png once).
QtObject {
    id: notif

    property bool popup: false
    property bool leaving: false        // popup out-animation in flight
    property bool held: false           // hovered/pressed popup: expiry paused
    property bool closed: false
    property bool synthetic: false      // injected through IPC (no DBus object behind it)
    property var locks: new Set()

    property date time: new Date()
    property string timeStr: "now"

    property Notification notification: null
    property string id: ""
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string appName: ""
    property string desktopEntry: ""
    property string image: ""
    property var hints: ({})
    property real expireTimeout: -1
    property int urgency: NotificationUrgency.Normal
    property bool resident: false
    property bool hasActionIcons: false
    property list<var> actions: []

    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property bool low: urgency === NotificationUrgency.Low
    readonly property int effectiveTimeout: {
        if (critical)
            return Config.notifs.criticalTimeout ?? 0;
        if (expireTimeout > 0)
            return expireTimeout;
        return Config.notifs.defaultTimeout ?? 5000;
    }

    readonly property Timer timeStrTimer: Timer {
        running: !notif.closed
        repeat: true
        interval: 5000
        onTriggered: notif.updateTimeStr()
    }

    readonly property Timer timer: Timer {
        running: notif.popup && !notif.leaving && !notif.held && notif.effectiveTimeout > 0
        interval: Math.max(notif.effectiveTimeout, 500)
        onTriggered: notif.dismissPopup()
    }

    readonly property Timer leaveTimer: Timer {
        interval: 120
        onTriggered: {
            notif.popup = false;
            notif.leaving = false;
        }
    }

    // Hidden click-through window that renders the image once so it can be saved to the cache.
    readonly property LazyLoader imageCacher: LazyLoader {
        active: false

        PanelWindow {
            implicitWidth: 96
            implicitHeight: 96
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "quantum-moon-notifimage"

            Image {
                id: grabImage

                property bool done: false

                function tryCache(): void {
                    if (done || status !== Image.Ready || width !== 96 || height !== 96)
                        return;
                    done = true;
                    const target = notif.cachePath();
                    grabToImage(result => {
                        if (result.saveToFile(target))
                            notif.image = target;
                        notif.imageCacher.active = false;
                    });
                }

                anchors.fill: parent
                source: notif.image
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                opacity: 0.01

                onStatusChanged: {
                    if (status === Image.Error)
                        notif.imageCacher.active = false;
                    else
                        tryCache();
                }
                onWidthChanged: tryCache()
                onHeightChanged: tryCache()
            }
        }
    }

    readonly property Connections conn: Connections {
        target: notif.notification

        function onClosed(): void {
            notif.close();
        }
        function onSummaryChanged(): void {
            notif.summary = notif.notification.summary;
        }
        function onBodyChanged(): void {
            notif.body = notif.notification.body;
        }
        function onAppIconChanged(): void {
            notif.appIcon = notif.notification.appIcon;
        }
        function onAppNameChanged(): void {
            notif.appName = notif.notification.appName;
        }
        function onImageChanged(): void {
            notif.image = notif.notification.image;
            notif.maybeCacheImage();
        }
        function onExpireTimeoutChanged(): void {
            notif.expireTimeout = notif.notification.expireTimeout;
        }
        function onUrgencyChanged(): void {
            notif.urgency = notif.notification.urgency;
        }
        function onResidentChanged(): void {
            notif.resident = notif.notification.resident;
        }
        function onHasActionIconsChanged(): void {
            notif.hasActionIcons = notif.notification.hasActionIcons;
        }
        function onActionsChanged(): void {
            notif.actions = notif.mapActions();
        }
        function onHintsChanged(): void {
            notif.hints = notif.notification.hints;
        }
    }

    function mapActions(): list<var> {
        if (!notification)
            return [];
        return notification.actions.map(a => ({
            identifier: a.identifier,
            text: a.text,
            invoke: () => a.invoke()
        }));
    }

    function cachePath(): string {
        const key = appName + summary + id + image;
        let h1 = 0xdeadbeef, h2 = 0x41c6ce57, ch;
        for (let i = 0; i < key.length; i++) {
            ch = key.charCodeAt(i);
            h1 = Math.imul(h1 ^ ch, 2654435761);
            h2 = Math.imul(h2 ^ ch, 1597334677);
        }
        h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
        h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
        h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
        h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
        const hash = (h2 >>> 0).toString(16).padStart(8, "0") + (h1 >>> 0).toString(16).padStart(8, "0");
        return `${Paths.cache}/notifs/${hash}.png`;
    }

    function maybeCacheImage(): void {
        if (image && image.startsWith("image://") && !image.startsWith("image://icon/"))
            imageCacher.active = true;
    }

    function updateTimeStr(): void {
        const m = Math.floor((Date.now() - time.getTime()) / 60000);
        if (m < 1) {
            timeStr = "now";
            timeStrTimer.interval = 5000;
            return;
        }
        const h = Math.floor(m / 60);
        const d = Math.floor(h / 24);
        if (d > 0) {
            timeStr = `${d}d`;
            timeStrTimer.interval = 3600000;
        } else if (h > 0) {
            timeStr = `${h}h`;
            timeStrTimer.interval = 300000;
        } else {
            timeStr = `${m}m`;
            timeStrTimer.interval = m < 10 ? 30000 : 60000;
        }
    }

    // Default action = "default" identifier, else the first action.
    function defaultAction(): var {
        return actions.find(a => a.identifier === "default") ?? actions[0] ?? null;
    }

    function invokeAction(identifier: string): bool {
        const a = actions.find(x => x.identifier === identifier);
        if (!a || typeof a.invoke !== "function")
            return false;
        a.invoke();
        return true;
    }

    function dismissPopup(): void {
        if (!popup || leaving)
            return;
        leaving = true;
        leaveTimer.restart();
    }

    function lock(item: var): void {
        locks.add(item);
    }

    function unlock(item: var): void {
        locks.delete(item);
        if (closed)
            close();
    }

    function close(): void {
        closed = true;
        popup = false;
        leaving = false;
        if (locks.size === 0)
            Notifs.remove(this);
    }

    Component.onCompleted: {
        if (!notification) {
            updateTimeStr();
            return;
        }
        id = String(notification.id);
        summary = notification.summary;
        body = notification.body;
        appIcon = notification.appIcon;
        appName = notification.appName;
        desktopEntry = notification.desktopEntry ?? "";
        image = notification.image;
        expireTimeout = notification.expireTimeout;
        hints = notification.hints;
        urgency = notification.urgency;
        resident = notification.resident;
        hasActionIcons = notification.hasActionIcons;
        actions = mapActions();
        maybeCacheImage();
        updateTimeStr();
    }
}
