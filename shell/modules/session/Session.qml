import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services

// Power menu ("session" drawer, right centre): vertical column of equal hex buttons.
Item {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property int buttonHeight: 72
    readonly property real buttonWidth: Theme.hexWidth(buttonHeight)
    property int current: 0
    property int pendingIndex: -1

    readonly property list<var> entries: [
        { id: "lock", icon: "lock", label: "Lock", destructive: false },
        { id: "logout", icon: "logout", label: "Log out", destructive: true },
        { id: "suspend", icon: "bedtime", label: "Suspend", destructive: false },
        { id: "hibernate", icon: "ac_unit", label: "Hibernate", destructive: false },
        { id: "reboot", icon: "restart_alt", label: "Reboot", destructive: true },
        { id: "shutdown", icon: "power_settings_new", label: "Shut down", destructive: true }
    ]

    implicitWidth: frame.implicitWidth + Theme.spaceMd
    implicitHeight: frame.implicitHeight

    function reveal(): void {
        root.current = 0;
        root.pendingIndex = -1;
        root.forceActiveFocus();
        reveal.trigger();
    }

    function commandFor(id: string): var {
        const c = Config.session?.commands?.[id];
        return Array.isArray(c) && c.length > 0 ? c : null;
    }

    function activate(index: int): void {
        const e = root.entries[index];
        if (!e)
            return;
        if (e.destructive && root.pendingIndex !== index) {
            root.pendingIndex = index;
            confirmTimer.restart();
            return;
        }
        confirmTimer.stop();
        root.pendingIndex = -1;
        root.run(e.id);
    }

    function run(id: string): void {
        if (id === "lock" && !root.commandFor("lock")) {
            Lock.lock();
            return;
        }
        const cmd = root.commandFor(id);
        if (!cmd) {
            Toaster.toast("Session", `No command configured for ${id}`, "error", "warn", 0);
            return;
        }
        if (root.visibilities)
            root.visibilities.session = false;
        Quickshell.execDetached(cmd);
    }

    function close(): void {
        if (root.visibilities)
            root.visibilities.session = false;
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Down:
        case Qt.Key_J:
        case Qt.Key_Tab:
            root.current = (root.current + 1) % root.entries.length;
            break;
        case Qt.Key_Up:
        case Qt.Key_K:
        case Qt.Key_Backtab:
            root.current = (root.current + root.entries.length - 1) % root.entries.length;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.activate(root.current);
            break;
        case Qt.Key_Escape:
            if (root.pendingIndex >= 0) {
                root.pendingIndex = -1;
                confirmTimer.stop();
            } else {
                root.close();
            }
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Timer {
        id: confirmTimer
        interval: 2000
        onTriggered: root.pendingIndex = -1
    }

    Rectangle {
        readonly property real sw: root.screen?.width ?? 4096
        readonly property real sh: root.screen?.height ?? 4096
        x: -sw
        y: -sh
        width: sw * 2
        height: sh * 2
        z: -1
        color: Theme.alpha(Theme.scrim, 0.4)
    }

    NomaiFrame {
        id: frame

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        padding: Theme.spaceSm
        chamfer: Theme.chamferMd
        corners: 9
        fill: Theme.alpha(Theme.ink1, 0.96)
        glow: true
        ticks: true
        // Don't clip tooltips that sit to the left of the column.
        clip: false

        GlyphReveal {
            id: reveal
            autoTrigger: false

            Column {
                id: column
                spacing: Theme.spaceSm
                // Let raised rows paint tooltips over neighbours.
                z: 0

                Repeater {
                    model: root.entries

                    Item {
                        id: entry

                        required property var modelData
                        required property int index

                        readonly property bool armed: root.pendingIndex === index
                        readonly property bool focused: root.current === index
                        readonly property bool tipUp: button.hovered || entry.armed || entry.focused

                        width: root.buttonWidth
                        height: root.buttonHeight
                        z: tipUp ? (1000 - index) : 0

                        HexButton {
                            id: button

                            width: root.buttonWidth
                            height: root.buttonHeight
                            icon: entry.armed ? "priority_high" : entry.modelData.icon
                            iconSize: 28
                            padding: Theme.spaceMd
                            shape: "hex"
                            glow: entry.focused || entry.armed
                            active: entry.focused && !entry.armed
                            danger: entry.modelData.destructive && (entry.armed || hovered)
                            accent: entry.armed ? Theme.ember : (entry.modelData.destructive && hovered ? Theme.danger : Theme.line)
                            tooltip: ""
                            onHoveredChanged: {
                                if (hovered)
                                    root.current = entry.index;
                            }
                            onClicked: {
                                root.current = entry.index;
                                root.activate(entry.index);
                            }
                        }

                        NomaiTooltip {
                            anchorItem: button
                            text: entry.armed ? `${entry.modelData.label}: again to confirm` : entry.modelData.label
                            show: button.hovered || entry.armed
                            delay: entry.armed ? 0 : 120
                            place: "left"
                            gap: Theme.spaceMd
                        }

                        Rectangle {
                            anchors.fill: button
                            anchors.margins: 8
                            color: Theme.alpha(Theme.ember, 0.22)
                            visible: entry.armed
                            z: -1
                        }
                    }
                }
            }
        }
    }

    focus: true
    Component.onCompleted: forceActiveFocus()
}
