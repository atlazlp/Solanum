import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme

// One row of a NomaiMenu: icon, label, checkmark, submenu chevron.
Item {
    id: root

    required property QsMenuEntry entry
    property int menuWidth: 220

    signal triggered()
    signal openSubmenu()

    implicitWidth: menuWidth
    implicitHeight: entry.isSeparator ? 7 : row.implicitHeight + Theme.spaceSm * 2

    NomaiDivider {
        visible: root.entry.isSeparator
        anchors.centerIn: parent
        width: parent.width * 0.6
        segments: 3
    }

    NomaiFrame {
        anchors.fill: parent
        visible: !root.entry.isSeparator
        padding: 0
        chamfer: Theme.chamferSm
        fill: hover.hovered ? Theme.ink2 : "transparent"
        lineOpacity: hover.hovered ? 1 : 0
        enabled: root.entry.enabled
        opacity: root.entry.enabled ? 1 : 0.45

        Row {
            id: row
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spaceSm
            anchors.rightMargin: Theme.spaceSm
            spacing: Theme.spaceSm

            GlyphIcon {
                visible: root.entry.buttonType !== QsMenuButtonType.None
                icon: root.entry.buttonType === QsMenuButtonType.RadioButton ? (root.entry.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked") : (root.entry.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                size: Theme.sizeBody
                color: root.entry.checkState === Qt.Checked ? Theme.line : Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }

            IconImage {
                visible: root.entry.icon !== ""
                source: root.entry.icon
                implicitSize: Theme.sizeBody * 1.4
                anchors.verticalCenter: parent.verticalCenter
            }

            GlyphText {
                text: root.entry.text
                width: parent.width - (chev.visible ? chev.width + parent.spacing : 0) - (root.entry.icon !== "" ? Theme.sizeBody * 1.4 + parent.spacing : 0) - (root.entry.buttonType !== QsMenuButtonType.None ? Theme.sizeBody * 1.5 + parent.spacing : 0)
                anchors.verticalCenter: parent.verticalCenter
            }

            GlyphIcon {
                id: chev
                visible: root.entry.hasChildren
                icon: "chevron_right"
                size: Theme.sizeBody
                color: Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                if (root.entry.hasChildren)
                    root.openSubmenu();
                else {
                    root.entry.triggered();
                    root.triggered();
                }
            }
        }
    }
}
