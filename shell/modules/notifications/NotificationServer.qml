import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services

// Owns org.freedesktop.Notifications. Only instantiated when DevFlags.notificationServer is true
// (never in dev mode, where another shell holds the bus name). Incoming notifications are handed
// to the Notifs singleton, which tracks, persists and logs them.
Scope {
    id: root

    Loader {
        active: DevFlags.notificationServer && Config.notifs.enabled !== false

        sourceComponent: NotificationServer {
            keepOnReload: false
            actionsSupported: true
            actionIconsSupported: true
            bodyHyperlinksSupported: true
            bodyImagesSupported: true
            bodyMarkupSupported: true
            imageSupported: true
            persistenceSupported: true

            onNotification: notif => Notifs.add(notif)
        }
    }
}
