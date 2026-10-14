import QtQuick
import qs.theme
import qs.components

// DBusMenu of the tray item passed as the host's `payload`.
Item {
    id: root

    property var host: null
    readonly property var trayItem: host?.payload ?? null

    implicitWidth: menu.implicitWidth
    implicitHeight: menu.implicitHeight

    NomaiMenu {
        id: menu
        menu: root.trayItem?.menu ?? null
        menuWidth: 220
        onClosed: root.host?.hide()
    }
}
