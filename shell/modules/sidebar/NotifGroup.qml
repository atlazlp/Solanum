pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils

// Notifications of one app: hex app icon + count header, preview of the newest two, expandable.
Column {
    id: root

    required property var group      // { app, desktopEntry, appIcon, notifs, latest }
    property bool expanded: false
    readonly property int previewCount: 2
    readonly property list<var> shown: expanded ? group.notifs : group.notifs.slice(0, previewCount)
    readonly property string iconSrc: {
        const ai = group.appIcon;
        if (ai) {
            if (ai.startsWith("/") || ai.startsWith("file://"))
                return ai;
            const p = Quickshell.iconPath(ai, true);
            if (p)
                return p;
        }
        return Icons.getAppIcon(group.desktopEntry || group.app, "");
    }

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    Item {
        id: header
        width: parent.width
        height: 40

        NomaiFrame {
            id: hex
            width: 32
            height: 32
            shape: "hex"
            padding: 0
            fill: Theme.ink2
            lineColor: Theme.line
            lineOpacity: 0.8
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.centerIn: parent
                visible: root.iconSrc !== "" && status === Image.Ready
                source: root.iconSrc
                width: 18
                height: 18
                sourceSize: Qt.size(36, 36)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            GlyphIcon {
                anchors.centerIn: parent
                visible: root.iconSrc === ""
                icon: Icons.getNotifIcon(root.group.notifs[0]?.summary ?? "", false)
                color: Theme.line
                fill: 1
                size: 16
            }
        }

        GlyphText {
            id: name
            anchors.left: hex.right
            anchors.leftMargin: Theme.spaceSm
            anchors.right: count.left
            anchors.rightMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            text: root.group.app
            role: "label"
        }

        NomaiFrame {
            id: count
            anchors.right: expand.left
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            shape: "hex"
            padding: 0
            width: 24
            height: 20
            fill: Theme.alpha(Theme.line, 0.14)
            lineColor: Theme.line
            lineOpacity: 0.6

            GlyphText {
                anchors.centerIn: parent
                text: root.group.notifs.length
                role: "label"
                font.letterSpacing: 0
            }
        }

        HexButton {
            id: expand
            anchors.right: closeBtn.left
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            icon: root.expanded ? "expand_less" : "expand_more"
            flat: true
            padding: 2
            visible: root.group.notifs.length > root.previewCount
            onClicked: root.expanded = !root.expanded
        }

        HexButton {
            id: closeBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            flat: true
            padding: 2
            tooltip: "Dismiss all from " + root.group.app
            onClicked: Notifs.clearApp(root.group.app)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: count.right
            height: parent.height
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spaceXs
        clip: true

        move: Transition {
            NumberAnimation { properties: "y"; duration: Motion.normal; easing.type: Motion.enter }
        }

        Repeater {
            model: root.shown

            Notif {}
        }
    }

    GlyphText {
        visible: !root.expanded && root.group.notifs.length > root.previewCount
        text: `+${root.group.notifs.length - root.previewCount} more`
        role: "label"
        dim: true
        leftPadding: Theme.spaceSm
    }
}
