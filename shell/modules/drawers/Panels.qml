pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.services

// Panel slots. Each slot is a Loader keyed by a DrawerVisibilities flag; the file at the well-known
// path is loaded when the drawer opens and unloaded after the close animation. A missing file
// only logs a warning. The loaded root item receives `screen`, `visibilities` and `slot`
// if it declares those (plain, non-required) properties.
Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities

    readonly property alias dashboard: dashboard
    readonly property alias quantumMoon: quantumMoon
    readonly property alias notifications: notifications
    readonly property alias osd: osd
    readonly property alias session: session
    readonly property alias sidebar: sidebar
    readonly property alias utilities: utilities
    readonly property alias launcher: launcher
    readonly property alias windowPicker: windowPicker
    readonly property alias shipLog: shipLog
    readonly property alias services: services
    readonly property alias kvm: kvm
    readonly property alias audio: audio
    readonly property alias updates: updates
    readonly property alias settings: settings

    readonly property list<Item> slots: [dashboard, quantumMoon, notifications, osd, session, sidebar, utilities, launcher, windowPicker, shipLog, services, kvm, audio, updates, settings]

    function slotFor(name: string): Item {
        return slots.find(s => s.name === name) ?? null;
    }

    function anyHovered(): bool {
        return slots.some(s => s.visible && s.hovered);
    }

    // ---- top ----
    PanelSlot {
        id: dashboard
        name: "dashboard"
        source: "../dashboard/Dashboard.qml"
        open: root.visibilities.dashboard
        edge: "top"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    PanelSlot {
        id: quantumMoon
        name: "quantumMoon"
        source: "../quantummoon/QmPanel.qml"
        open: root.visibilities.quantumMoon
        edge: "top"
        anchors.right: parent.right
        anchors.top: parent.top
    }

    PanelSlot {
        id: notifications
        name: "notifications"
        source: "../notifications/Popups.qml"
        open: Screens.isEnabled("notifications", root.screen.name) && Notifs.count > 0 && !root.visibilities.sidebar
        edge: "right"
        anchors.right: parent.right
        anchors.top: quantumMoon.visible ? quantumMoon.bottom : parent.top
    }

    // ---- right ----
    PanelSlot {
        id: sidebar
        name: "sidebar"
        source: "../sidebar/Sidebar.qml"
        open: root.visibilities.sidebar
        edge: "right"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    PanelSlot {
        id: session
        name: "session"
        source: "../session/Session.qml"
        open: root.visibilities.session
        edge: "right"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }

    PanelSlot {
        id: osd
        name: "osd"
        source: "../osd/Osd.qml"
        open: root.visibilities.osd
        edge: "right"
        anchors.right: parent.right
        anchors.rightMargin: (session.visible ? session.width : 0) + (sidebar.visible ? sidebar.width : 0)
        anchors.verticalCenter: parent.verticalCenter
    }

    PanelSlot {
        id: utilities
        name: "utilities"
        source: "../utilities/Utilities.qml"
        open: root.visibilities.utilities
        edge: "bottom"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    // ---- bottom ----
    PanelSlot {
        id: launcher
        name: "launcher"
        source: "../launcher/Launcher.qml"
        open: root.visibilities.launcher
        edge: "bottom"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    PanelSlot {
        id: windowPicker
        name: "windowPicker"
        source: "../windowpicker/WindowPicker.qml"
        open: root.visibilities.windowPicker
        edge: "bottom"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    // ---- centre ----
    PanelSlot {
        id: shipLog
        name: "shipLog"
        source: "../shiplog/ShipLog.qml"
        open: root.visibilities.shipLog
        edge: "center"
        anchors.centerIn: parent
    }

    PanelSlot {
        id: services
        name: "services"
        source: "../panels/ServicesPanel.qml"
        open: root.visibilities.services
        edge: "center"
        anchors.centerIn: parent
    }

    PanelSlot {
        id: kvm
        name: "kvm"
        source: "../panels/KvmPanel.qml"
        open: root.visibilities.kvm
        edge: "center"
        anchors.centerIn: parent
    }

    PanelSlot {
        id: audio
        name: "audio"
        source: "../panels/AudioPanel.qml"
        open: root.visibilities.audio
        edge: "center"
        anchors.centerIn: parent
    }

    PanelSlot {
        id: updates
        name: "updates"
        source: "../updates/UpdatesPanel.qml"
        open: root.visibilities.updates
        edge: "center"
        anchors.centerIn: parent
    }

    PanelSlot {
        id: settings
        name: "settings"
        source: "../settings/Settings.qml"
        open: root.visibilities.settings
        edge: "center"
        anchors.centerIn: parent
    }

    component PanelSlot: Item {
        id: slot

        required property string name
        required property string source
        property bool open: false
        property string edge: "top"     // top | right | bottom | center
        readonly property bool loaded: loader.status === Loader.Ready
        readonly property bool missing: loader.status === Loader.Error
        readonly property alias item: loader.item
        readonly property alias hovered: hover.hovered
        property real progress: open ? 1 : 0

        readonly property bool keepAlive: progress > 0.001

        visible: keepAlive && !missing
        implicitWidth: loader.item?.implicitWidth ?? 0
        implicitHeight: loader.item?.implicitHeight ?? 0
        width: edge === "right" && anchors.bottom !== undefined ? implicitWidth : implicitWidth
        height: implicitHeight
        opacity: progress
        z: edge === "center" ? Theme.zModal : Theme.zPanel

        transform: Translate {
            x: slot.edge === "right" ? Motion.panelTranslate * (1 - slot.progress) : 0
            y: slot.edge === "top" ? -Motion.panelTranslate * (1 - slot.progress) : (slot.edge === "bottom" ? Motion.panelTranslate * (1 - slot.progress) : 0)
        }

        Behavior on progress {
            NumberAnimation {
                duration: slot.open ? Motion.panelOpen : Motion.panelClose
                easing.type: slot.open ? Motion.enter : Motion.exit
            }
        }

        Loader {
            id: loader

            anchors.fill: parent
            active: slot.open || slot.keepAlive
            source: active ? Qt.resolvedUrl(slot.source) : ""

            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn(`Panels: no panel at ${slot.source} (drawer "${slot.name}")`);
            }

            onLoaded: {
                if (!item)
                    return;
                if ("screen" in item)
                    item.screen = root.screen;
                if ("visibilities" in item)
                    item.visibilities = root.visibilities;
                if ("slot" in item)
                    item.slot = slot;
                if (typeof item.reveal === "function")
                    item.reveal();
            }
        }

        HoverHandler {
            id: hover
        }
    }
}
