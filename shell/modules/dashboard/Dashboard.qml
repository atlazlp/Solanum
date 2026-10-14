pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services

// Dashboard panel (top centre slot): Dash / Performance / Weather tabs.
NomaiFrame {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    property int tab: 0
    readonly property list<var> tabs: [
        { id: "dash", icon: "dashboard", label: "Dash" },
        { id: "performance", icon: "monitoring", label: "Performance" },
        { id: "weather", icon: "partly_cloudy_day", label: "Weather" }
    ]

    function reveal(): void {
        if (typeof pages.current.trigger === "function")
            pages.current.trigger();
    }

    onTabChanged: reveal()

    padding: Theme.spaceLg
    chamfer: Theme.chamferLg
    corners: 4 | 8         // bottom corners only: the panel hangs from the bar
    fill: Theme.ink
    glow: true
    ticks: true

    Component.onCompleted: {
        SystemUsage.refCount++;
        NetworkUsage.refCount++;
        Audio.peakRefs++;
        if (!Weather.hasData && !Weather.loading)
            Weather.reload();
    }
    Component.onDestruction: {
        SystemUsage.refCount--;
        NetworkUsage.refCount--;
        Audio.peakRefs--;
    }

    Column {
        spacing: Theme.spaceMd

        // Tab strip: hex buttons joined by a 1 px connector; the active tab's segment glows.
        Item {
            id: tabStrip

            width: Math.max(tabRow.implicitWidth, pages.width)
            implicitHeight: tabRow.implicitHeight + Theme.spaceSm + 2

            Row {
                id: tabRow

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spaceLg

                Repeater {
                    id: tabRepeater
                    model: root.tabs

                    HexButton {
                        id: tabBtn

                        required property var modelData
                        required property int index

                        shape: "hex"
                        icon: modelData.icon
                        text: modelData.label
                        active: root.tab === index
                        flat: !active
                        glow: active
                        padding: Theme.spaceSm
                        onClicked: root.tab = index
                        Keys.onLeftPressed: root.tab = (root.tab + root.tabs.length - 1) % root.tabs.length
                        Keys.onRightPressed: root.tab = (root.tab + 1) % root.tabs.length

                        // Connector to the next tab
                        Rectangle {
                            visible: tabBtn.index < root.tabs.length - 1
                            anchors.left: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: tabRow.spacing
                            height: 1
                            color: Theme.lineDim
                        }
                    }
                }
            }

            // Edge connector under the strip with a glowing segment under the active tab
            Rectangle {
                id: rail
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.lineDim
            }

            Rectangle {
                readonly property Item btn: tabRepeater.count > root.tab ? tabRepeater.itemAt(root.tab) : null
                anchors.bottom: parent.bottom
                x: btn ? tabRow.x + btn.x : 0
                width: btn ? btn.width : 0
                height: 2
                color: Theme.line

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + Theme.glowWidth
                    height: Theme.glowWidth
                    color: Theme.glow
                }

                Behavior on x { NumberAnimation { duration: Motion.normal; easing.type: Motion.slide } }
                Behavior on width { NumberAnimation { duration: Motion.normal; easing.type: Motion.slide } }
            }
        }

        Item {
            id: pages

            readonly property Item current: root.tab === 1 ? perf : (root.tab === 2 ? weatherTab : dash)
            readonly property int gap: Theme.spaceLg

            implicitWidth: current.implicitWidth
            implicitHeight: current.implicitHeight
            width: implicitWidth
            height: implicitHeight

            Behavior on implicitWidth { NumberAnimation { duration: Motion.normal; easing.type: Motion.enter } }
            Behavior on implicitHeight { NumberAnimation { duration: Motion.normal; easing.type: Motion.enter } }

            // Dash: three columns placed by hand so GlyphReveal can stagger them.
            GlyphReveal {
                id: dash

                autoTrigger: false
                visible: opacity > 0
                opacity: root.tab === 0 ? 1 : 0
                implicitWidth: rightCol.x + rightCol.implicitWidth
                implicitHeight: Math.max(leftCol.implicitHeight, media.implicitHeight, rightCol.implicitHeight)
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.fade } }

                Column {
                    id: leftCol
                    x: 0
                    spacing: Theme.spaceMd
                    DateTime {}
                    Calendar {}
                }

                Rectangle { x: leftCol.implicitWidth + pages.gap; width: 1; height: dash.implicitHeight; color: Theme.lineDim; opacity: 0.6 }

                Media {
                    id: media
                    x: leftCol.implicitWidth + pages.gap * 2 + 1
                    y: (dash.implicitHeight - implicitHeight) / 2
                }

                Rectangle { x: media.x + media.implicitWidth + pages.gap; width: 1; height: dash.implicitHeight; color: Theme.lineDim; opacity: 0.6 }

                Column {
                    id: rightCol
                    x: media.x + media.implicitWidth + pages.gap * 2 + 1
                    spacing: Theme.spaceMd
                    WeatherPane { compact: true }
                    Resources {}
                }
            }

            Performance {
                id: perf

                visible: opacity > 0
                opacity: root.tab === 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.fade } }
            }

            WeatherPane {
                id: weatherTab

                compact: false
                visible: opacity > 0
                opacity: root.tab === 2 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.fade } }
            }
        }
    }
}
