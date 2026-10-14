import QtQuick
import qs.theme
import qs.components
import qs.services

// Details of the focused window.
Column {
    id: root

    property var host: null
    readonly property var tl: Hypr.activeToplevel
    readonly property var ipc: tl?.lastIpcObject ?? ({})
    spacing: Theme.spaceXs
    width: 320

    Row {
        spacing: Theme.spaceSm

        AppIcon {
            appId: String(root.ipc.class ?? "")
            size: 28
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: root.width - 28 - parent.spacing

            GlyphText {
                text: root.tl?.title || "Desktop"
                role: "large"
                width: parent.width
            }

            GlyphText {
                text: String(root.ipc.class ?? "")
                role: "mono"
                dim: true
                width: parent.width
            }
        }
    }

    SectionHeader { text: "Window" }

    Repeater {
        model: [
            ["Workspace", String(root.ipc.workspace?.name ?? "")],
            ["Monitor", String(root.tl?.monitor?.name ?? "")],
            ["PID", String(root.ipc.pid ?? "")],
            ["Size", root.ipc.size ? `${root.ipc.size[0]} x ${root.ipc.size[1]}` : ""],
            ["Floating", root.ipc.floating ? "yes" : "no"],
            ["Fullscreen", root.ipc.fullscreen ? "yes" : "no"],
            ["XWayland", root.ipc.xwayland ? "yes" : "no"]
        ]

        Row {
            required property var modelData
            spacing: Theme.spaceSm
            visible: modelData[1] !== ""

            GlyphText {
                text: modelData[0]
                role: "small"
                dim: true
                width: 80
            }

            GlyphText {
                text: modelData[1]
                role: "mono"
            }
        }
    }

    Row {
        spacing: Theme.spaceSm
        topPadding: Theme.spaceXs

        HexButton {
            icon: "close"
            text: "Close"
            danger: true
            padding: Theme.spaceXs
            onClicked: {
                Hypr.dispatch("killactive");
                root.host?.hide();
            }
        }

        HexButton {
            icon: root.ipc.floating ? "grid_view" : "picture_in_picture_alt"
            text: root.ipc.floating ? "Tile" : "Float"
            padding: Theme.spaceXs
            onClicked: Hypr.dispatch("togglefloating")
        }

        HexButton {
            icon: "fullscreen"
            text: "Fullscreen"
            padding: Theme.spaceXs
            onClicked: Hypr.dispatch("fullscreen 0")
        }
    }
}
