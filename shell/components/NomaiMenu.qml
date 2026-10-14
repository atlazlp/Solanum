import QtQuick
import Quickshell
import qs.theme

// Renders a QsMenuHandle tree (DBusMenu / tray menus) as a stack of NomaiMenuItems with a Back row for submenus.
Column {
    id: root

    property QsMenuHandle menu: null
    property int menuWidth: 220
    property var stack: []
    readonly property QsMenuHandle current: stack.length ? stack[stack.length - 1] : menu

    signal closed()

    spacing: 1

    function push(handle: QsMenuHandle): void {
        stack = stack.concat([handle]);
    }

    function pop(): void {
        if (stack.length)
            stack = stack.slice(0, -1);
    }

    function reset(): void {
        stack = [];
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Item {
        visible: root.stack.length > 0
        width: root.menuWidth
        height: visible ? back.implicitHeight : 0

        HexButton {
            id: back
            flat: true
            icon: "chevron_left"
            text: "Back"
            padding: Theme.spaceXs
            width: parent.width
            onClicked: root.pop()
        }
    }

    Repeater {
        model: opener.children

        NomaiMenuItem {
            required property QsMenuEntry modelData
            entry: modelData
            menuWidth: root.menuWidth
            onOpenSubmenu: root.push(modelData)
            onTriggered: root.closed()
        }
    }
}
