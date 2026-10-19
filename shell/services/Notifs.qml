pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import qs.services

// Notification model: the list of open notifications (live + restored from state), popups, DND.
// The DBus server itself lives in modules/notifications/NotificationServer.qml (gated by
// DevFlags.notificationServer) and calls `add()`. Every notification is also recorded in ShipLog.
Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: list.filter(n => n.popup)
    readonly property int count: notClosed.length
    readonly property int popupCount: popups.length
    property alias dnd: props.dnd
    property bool loaded: false
    property int syntheticSeq: 1

    // Groups (sidebar): one per app name, newest group first, entries newest first.
    readonly property list<var> groups: {
        const map = new Map();
        for (const n of notClosed) {
            const key = n.appName || "Unknown";
            if (!map.has(key))
                map.set(key, { app: key, desktopEntry: n.desktopEntry, appIcon: n.appIcon, notifs: [], latest: n.time.getTime() });
            const g = map.get(key);
            g.notifs.push(n);
            g.latest = Math.max(g.latest, n.time.getTime());
        }
        return [...map.values()].sort((a, b) => b.latest - a.latest);
    }

    function sidebarOpen(): bool {
        for (const v of Visibilities.screens.values())
            if (v.sidebar)
                return true;
        return false;
    }

    function shouldShowPopup(): bool {
        if (Config.notifs.enabled === false)
            return false;
        return !props.dnd && !sidebarOpen();
    }

    // Called by the NotificationServer module for each incoming DBus notification.
    function add(notification: Notification): void {
        notification.tracked = true;
        const n = notifComp.createObject(root, {
            notification: notification,
            popup: shouldShowPopup()
        });
        insert(n);
    }

    // Debug / scripting entry: a notification with no DBus object behind it.
    function inject(summary: string, body: string, app: string, urgency: int, actions: var): NotifData {
        const acts = (actions ?? []).map(a => ({
            identifier: a.identifier ?? a.id ?? a.text,
            text: a.text ?? a.identifier ?? "",
            invoke: () => Toaster.toast(summary, `Action "${a.text ?? a.identifier}" invoked`, "notifications", "info", 0)
        }));
        const n = notifComp.createObject(root, {
            synthetic: true,
            id: `synthetic-${Date.now()}-${syntheticSeq++}`,
            summary: summary ?? "",
            body: body ?? "",
            appName: app ?? "solanum",
            urgency: urgency ?? NotificationUrgency.Normal,
            actions: acts,
            popup: shouldShowPopup()
        });
        insert(n);
        return n;
    }

    function insert(n: NotifData): void {
        list = [n, ...list];
        trimPopups();
        ShipLog.record(n, !n.popup && props.dnd);
    }

    function trimPopups(): void {
        const max = Config.notifs.maxPopups ?? 5;
        const open = popups.filter(n => !n.leaving);
        for (let i = max; i < open.length; i++)
            open[i].dismissPopup();
    }

    function remove(n: NotifData): void {
        if (!list.includes(n))
            return;
        list = list.filter(x => x !== n);
        n.notification?.dismiss();
        n.destroy();
    }

    function clear(): void {
        for (const n of list.slice())
            n.close();
    }

    function clearApp(app: string): void {
        for (const n of list.slice())
            if ((n.appName || "Unknown") === app)
                n.close();
    }

    function dismissPopups(): void {
        for (const n of popups)
            n.dismissPopup();
    }

    // When the user focuses an application window after a toast, clear the toast stack.
    readonly property var focusToplevel: Hypr.activeToplevel
    onFocusToplevelChanged: {
        if (!loaded || popupCount === 0)
            return;
        if (!focusToplevel)
            return;
        dismissPopups();
    }

    function launchApp(appName: string, desktopEntry: string): bool {
        let entry = null;
        if (desktopEntry)
            entry = DesktopEntries.byId(desktopEntry) ?? DesktopEntries.heuristicLookup(desktopEntry);
        if (!entry && appName)
            entry = DesktopEntries.heuristicLookup(appName);
        if (!entry) {
            Toaster.toast("No app found", appName || desktopEntry || "", "search_off", "warn", 0);
            return false;
        }
        entry.execute();
        return true;
    }

    // Click: focus the running app (incl. window-group tabs); else default action / launch.
    function activate(n: NotifData): void {
        if (!n)
            return;
        if (Hypr.focusApp(n.appName, n.desktopEntry)) {
            n.dismissPopup();
            return;
        }
        if (Config.notifs.actionOnClick !== false) {
            const a = n.defaultAction();
            if (a) {
                a.invoke();
                n.close();
                return;
            }
        }
        launchApp(n.appName, n.desktopEntry);
        n.dismissPopup();
    }

    function byId(id: string): NotifData {
        return list.find(n => n.id === id) ?? null;
    }

    onDndChanged: {
        if (!loaded)
            return;
        if (dnd) {
            dismissPopups();
            Toaster.toast("Do not disturb", "Popups off; signals still reach the ship log", "do_not_disturb_on", "info", 0);
        } else {
            Toaster.toast("Do not disturb off", "Popups are back", "do_not_disturb_off", "info", 0);
        }
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: storage.setText(JSON.stringify(root.notClosed.map(n => ({
            time: n.time.getTime(),
            id: n.id,
            summary: n.summary,
            body: n.body,
            appIcon: n.appIcon,
            appName: n.appName,
            desktopEntry: n.desktopEntry,
            image: n.image.startsWith("image://") ? "" : n.image,
            expireTimeout: n.expireTimeout,
            urgency: n.urgency,
            resident: n.resident,
            hasActionIcons: n.hasActionIcons,
            synthetic: true,
            actions: n.actions.map(a => ({ identifier: a.identifier, text: a.text }))
        }))))
    }

    PersistentProperties {
        id: props
        reloadableId: "notifs"
        property bool dnd: false
    }

    FileView {
        id: storage

        path: `${Paths.state}/notifs.json`
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                const restored = [];
                for (const raw of data) {
                    const n = notifComp.createObject(root, {
                        synthetic: true,
                        id: String(raw.id ?? ""),
                        time: new Date(raw.time ?? Date.now()),
                        summary: raw.summary ?? "",
                        body: raw.body ?? "",
                        appIcon: raw.appIcon ?? "",
                        appName: raw.appName ?? "",
                        desktopEntry: raw.desktopEntry ?? "",
                        image: raw.image ?? "",
                        expireTimeout: raw.expireTimeout ?? -1,
                        urgency: raw.urgency ?? NotificationUrgency.Normal,
                        resident: raw.resident ?? false,
                        hasActionIcons: raw.hasActionIcons ?? false,
                        actions: (raw.actions ?? []).map(a => ({ identifier: a.identifier, text: a.text, invoke: () => {} }))
                    });
                    n.updateTimeStr();
                    restored.push(n);
                }
                restored.sort((a, b) => b.time.getTime() - a.time.getTime());
                root.list = [...root.list, ...restored];
            } catch (e) {
                console.warn("Notifs: cannot parse", path, e);
            }
            root.loaded = true;
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => setText("[]"));
        }
    }

    IpcHandler {
        target: "notifs"

        function clear(): void {
            root.clear();
        }

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }

        function enableDnd(): void {
            root.dnd = true;
        }

        function disableDnd(): void {
            root.dnd = false;
        }

        function isDndEnabled(): bool {
            return root.dnd;
        }

        function count(): int {
            return root.count;
        }

        // Debug: `qs -c solanum ipc call notifs inject "Summary" "Body" "App"`
        function inject(summary: string, body: string, app: string): string {
            const n = root.inject(summary, body, app, NotificationUrgency.Normal, [{ identifier: "default", text: "Open" }, { identifier: "later", text: "Later" }]);
            return n.id;
        }

        function injectUrgent(summary: string, body: string, app: string): string {
            const n = root.inject(summary, body, app, NotificationUrgency.Critical, [{ identifier: "default", text: "Show" }]);
            return n.id;
        }

        function injectLow(summary: string, body: string, app: string): string {
            const n = root.inject(summary, body, app, NotificationUrgency.Low, []);
            return n.id;
        }
    }

    Component {
        id: notifComp
        NotifData {}
    }
}
