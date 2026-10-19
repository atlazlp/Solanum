pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.utils

// One popup notification. Slides in from the right (32 px, 180 ms) with a line-glow flash,
// slides out in 120 ms. Horizontal drag past a third of the width dismisses; vertical drag or
// the chevron expands the body; click runs the default action / launches the app.
Item {
    id: root

    required property NotifData modelData
    property bool expanded: false
    readonly property real dismissThreshold: width * 0.33
    readonly property color accent: modelData.critical ? Theme.ember : (modelData.low ? Theme.lineDim : Theme.line)
    readonly property string iconSrc: {
        const ai = modelData.appIcon;
        if (ai) {
            if (ai.startsWith("/") || ai.startsWith("file://"))
                return ai;
            const p = Quickshell.iconPath(ai, true);
            if (p)
                return p;
        }
        return Icons.getAppIcon(modelData.desktopEntry || modelData.appName, "");
    }
    readonly property bool hasImage: modelData.image !== "" && !modelData.image.startsWith("image://icon/")

    width: 380
    implicitHeight: frame.implicitHeight
    opacity: modelData.leaving ? 0 : 1
    x: 0
    transform: Translate {
        id: enterSlide
        x: 32
    }

    Component.onCompleted: {
        modelData.lock(root);
        enterAnim.start();
        glowFlash.start();
    }

    NumberAnimation {
        id: enterAnim
        target: enterSlide
        property: "x"
        to: 0
        duration: Motion.normal
        easing.type: Motion.slide
    }
    Component.onDestruction: modelData.unlock(root)

    Connections {
        target: root.modelData
        function onLeavingChanged(): void {
            if (root.modelData.leaving && !mouse.pressed && Math.abs(root.x) < root.dismissThreshold)
                root.x = 48;
        }
    }

    Behavior on x {
        enabled: !mouse.pressed
        NumberAnimation {
            duration: root.modelData.leaving ? 120 : Motion.normal
            easing.type: root.modelData.leaving ? Motion.exit : Motion.slide
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 120
            easing.type: Motion.exit
        }
    }

    SequentialAnimation {
        id: glowFlash
        NumberAnimation { target: frame; property: "glowOpacity"; from: 0.75; to: 0.18; duration: Motion.reveal; easing.type: Motion.exit }
    }

    NomaiFrame {
        id: frame

        width: parent.width
        padding: Theme.spaceMd
        chamfer: Theme.chamferMd
        fill: root.modelData.critical ? Theme.mix(Theme.ink1, Theme.ember, 0.08) : Theme.ink1
        lineColor: root.accent
        lineOpacity: root.modelData.low ? 0.8 : 1
        glow: !root.modelData.low
        ticks: true
        implicitHeight: row.implicitHeight + padding * 2

        Behavior on implicitHeight {
            NumberAnimation { duration: Motion.normal; easing.type: Motion.enter }
        }

        Row {
            id: row
            width: parent.width
            spacing: Theme.spaceMd

            // App icon in a small hex (or the notification image).
            Item {
                width: Theme.hexWidth(40)
                height: 40
                anchors.top: parent.top

                NomaiFrame {
                    anchors.fill: parent
                    shape: "hex"
                    padding: 0
                    fill: Theme.ink2
                    lineColor: root.accent
                    lineOpacity: 0.8
                    visible: !root.hasImage

                    Image {
                        anchors.centerIn: parent
                        visible: root.iconSrc !== "" && status === Image.Ready
                        source: root.iconSrc
                        width: 20
                        height: 20
                        sourceSize: Qt.size(40, 40)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    GlyphIcon {
                        anchors.centerIn: parent
                        visible: root.iconSrc === ""
                        icon: Icons.getNotifIcon(root.modelData.summary, root.modelData.critical)
                        color: root.accent
                        fill: 1
                        size: 18
                    }
                }

                NomaiFrame {
                    anchors.fill: parent
                    visible: root.hasImage
                    padding: 0
                    chamfer: Theme.chamferSm
                    fill: Theme.ink2
                    lineColor: root.accent
                    lineOpacity: 0.8

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: root.modelData.image
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(80, 80)
                        asynchronous: true
                    }
                }
            }

            Column {
                width: parent.width - 40 - Theme.spaceMd * 2 - chevron.width
                spacing: Theme.spaceXs

                Row {
                    width: parent.width
                    spacing: Theme.spaceSm

                    GlyphText {
                        text: root.modelData.appName || "notification"
                        role: "label"
                        dim: true
                        width: parent.width - timeText.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    GlyphText {
                        id: timeText
                        text: root.modelData.timeStr
                        role: "label"
                        dim: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                GlyphText {
                    text: root.modelData.summary
                    role: "large"
                    width: parent.width
                    wrapMode: root.expanded ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: root.expanded ? 6 : 1
                }

                GlyphText {
                    id: bodyText
                    visible: root.modelData.body !== ""
                    text: root.modelData.body
                    role: "small"
                    dim: true
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: root.expanded ? 40 : 2
                    textFormat: Text.StyledText
                    linkColor: Theme.spark
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                Flow {
                    id: actions
                    width: parent.width
                    spacing: Theme.spaceSm
                    visible: root.modelData.actions.length > 0
                    topPadding: Theme.spaceXs

                    Repeater {
                        model: root.modelData.actions

                        HexButton {
                            required property var modelData
                            text: modelData.text
                            padding: Theme.spaceXs + 1
                            maxWidth: 140
                            onClicked: {
                                modelData.invoke();
                                root.modelData.close();
                            }
                        }
                    }
                }
            }

            HexButton {
                id: chevron
                icon: root.expanded ? "expand_less" : "expand_more"
                flat: true
                padding: 2
                shape: "hex"
                anchors.top: parent.top
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    MouseArea {
        id: mouse

        property real startY: 0
        property bool vertical: false

        anchors.fill: frame
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true
        drag.target: root
        drag.axis: Drag.XAxis
        drag.threshold: 8

        onContainsMouseChanged: root.modelData.held = containsMouse || pressed
        onPressedChanged: root.modelData.held = containsMouse || pressed

        onPressed: event => {
            startY = event.y;
            vertical = false;
            if (event.button === Qt.MiddleButton)
                root.modelData.close();
        }
        onPositionChanged: event => {
            if (!pressed)
                return;
            const dy = event.y - startY;
            if (Math.abs(dy) > 24) {
                root.expanded = dy > 0;
                vertical = true;
            }
        }
        onReleased: {
            if (Math.abs(root.x) >= root.dismissThreshold) {
                root.x = root.x > 0 ? root.width * 1.2 : -root.width * 1.2;
                root.modelData.dismissPopup();
            } else {
                root.x = 0;
            }
        }
        onClicked: event => {
            if (event.button !== Qt.LeftButton || vertical || Math.abs(root.x) > 4)
                return;
            Notifs.activate(root.modelData);
        }
    }
}
