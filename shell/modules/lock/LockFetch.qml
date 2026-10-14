import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// fetch-style card: OS / WM / user / uptime next to the current planet logo, term0..7 swatches.
NomaiFrame {
    id: root

    property string osName: ""
    property string uptime: ""
    readonly property string wm: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"
    readonly property string user: Quickshell.env("USER") || ""

    padding: Theme.spaceMd
    fill: Theme.alpha(Theme.ink2, 0.9)
    lineOpacity: 0.5
    corners: 0

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m) ?? text().match(/^NAME="?([^"\n]*)"?/m);
            root.osName = m ? m[1] : "Linux";
        }
    }

    Process {
        id: uptimeProc

        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: root.uptime = text.trim().replace(/^up /, "").replace(/ weeks?/, "w").replace(/ days?/, "d").replace(/ hours?/, "h").replace(/ minutes?/, "m")
        }
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeProc.running = true
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spaceSm

        SectionHeader {
            text: "Ship"
        }

        Row {
            width: parent.width
            spacing: Theme.spaceMd

            Item {
                width: 56
                height: 56
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: QuantumMoon.logoPath ? `file://${QuantumMoon.logoPath}` : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    mipmap: true
                    sourceSize: Qt.size(112, 112)
                    visible: status === Image.Ready
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    icon: "public"
                    size: 36
                    color: Theme.lineDim
                    visible: !QuantumMoon.logoPath
                }
            }

            Column {
                width: parent.width - 56 - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                FetchLine { k: "OS"; v: root.osName }
                FetchLine { k: "WM"; v: root.wm }
                FetchLine { k: "USER"; v: root.user }
                FetchLine { k: "UP"; v: root.uptime }
                FetchLine { k: "PLANET"; v: QuantumMoon.displayName || QuantumMoon.slug || "—"; visible: QuantumMoon.slug !== "" }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceSm
            topPadding: Theme.spaceXs

            Repeater {
                model: 8

                Rectangle {
                    required property int index

                    width: 14
                    height: 14
                    color: Theme.term[index]
                    border.width: 1
                    border.color: Theme.alpha(Theme.lineDim, 0.6)
                }
            }
        }
    }

    component FetchLine: Row {
        property string k: ""
        property string v: ""

        width: parent.width
        spacing: Theme.spaceSm

        GlyphText {
            role: "mono"
            color: Theme.line
            text: k.padEnd(6, " ")
        }

        GlyphText {
            role: "mono"
            text: v
            width: parent.width - 60
        }
    }
}
