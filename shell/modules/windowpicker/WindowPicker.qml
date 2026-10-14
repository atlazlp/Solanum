pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.modules.launcher

// Window picker panel (bottom centre, drawer `windowPicker`): filter field + WindowList grouped by
// workspace. Enter focuses, Delete / hover button kills (KillConfirm), F2 / right-click edits.
Item {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property int panelWidth: Config.launcher.width ?? 640

    readonly property bool modalOpen: editor.open || killConfirm.open
    readonly property int modalHeight: editor.open ? 520 : 240

    implicitWidth: panelWidth
    implicitHeight: Math.max(frame.implicitHeight, modalOpen ? modalHeight : 0)

    focus: true
    Keys.forwardTo: [filter.input]

    function reveal(): void {
        list.revealNow();
        root.forceActiveFocus();
    }

    function close(): void {
        Visibilities.close("windowPicker", root.visibilities);
    }

    function focusRow(row: var): void {
        if (!row?.address)
            return;
        Hypr.dispatch(`focuswindow address:${row.address}`);
        close();
    }

    Connections {
        target: filter.input
        function onActiveFocusChanged(): void {
            if (filter.input.activeFocus && !editor.open && !killConfirm.open)
                root.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        if (editor.open || killConfirm.open)
            return;
        switch (event.key) {
        case Qt.Key_Escape:
            close();
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            list.activateCurrent();
            event.accepted = true;
            break;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            list.moveBy(-1);
            event.accepted = true;
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            list.moveBy(1);
            event.accepted = true;
            break;
        case Qt.Key_PageUp:
            list.moveBy(-list.maxShown);
            event.accepted = true;
            break;
        case Qt.Key_PageDown:
            list.moveBy(list.maxShown);
            event.accepted = true;
            break;
        case Qt.Key_Delete:
            list.killCurrent();
            event.accepted = true;
            break;
        case Qt.Key_F2:
            list.editCurrent();
            event.accepted = true;
            break;
        }
    }

    NomaiFrame {
        id: frame
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: implicitHeight
        padding: Theme.spaceLg
        chamfer: Theme.chamferLg
        fill: Theme.ink
        glow: true
        ticks: true
        implicitHeight: column.implicitHeight + padding * 2

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.spaceMd

            Row {
                width: parent.width
                spacing: Theme.spaceMd

                SectionHeader {
                    text: `Windows  ·  ${list.windowCount}`
                    anchors.verticalCenter: parent.verticalCenter
                }

                NomaiTextField {
                    id: filter
                    width: parent.width - parent.spacing - parent.children[0].implicitWidth
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "search"
                    placeholder: "Filter windows"
                    input.cursorVisible: true
                }
            }

            WindowList {
                id: list
                width: parent.width
                grouped: true
                query: filter.text
                active: root.visibilities?.windowPicker ?? true
                onFocusRequested: row => root.focusRow(row)
                onKillRequested: row => killConfirm.ask(row)
                onEditRequested: target => editor.edit(target)
            }

            GlyphText {
                text: "Enter focus  ·  Del kill  ·  F2 edit  ·  Esc close"
                role: "label"
                dim: true
            }
        }
    }

    ItemEditor {
        id: editor
        onClosed: root.forceActiveFocus()
    }

    KillConfirm {
        id: killConfirm
        onConfirmed: root.forceActiveFocus()
        onCancelled: root.forceActiveFocus()
    }
}
