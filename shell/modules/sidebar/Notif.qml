pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services

// One notification row inside a sidebar group. Swipe horizontally past a third of the width
// to close it; click runs the default action / launches the app.
Item {
    id: root

    required property NotifData modelData
    property bool expanded: false
    readonly property color accent: modelData.critical ? Theme.ember : (modelData.low ? Theme.lineDim : Theme.line)

    width: parent ? parent.width : 320
    implicitHeight: frame.implicitHeight
    clip: false

    Behavior on x {
        enabled: !mouse.pressed
        NumberAnimation { duration: Motion.fast; easing.type: Motion.exit }
    }

    NomaiFrame {
        id: frame

        width: parent.width
        padding: Theme.spaceSm
        chamfer: Theme.chamferSm
        corners: 5
        fill: mouse.containsMouse ? Theme.ink2 : Theme.ink0
        lineColor: root.accent
        lineOpacity: root.modelData.critical ? 0.9 : 0.35
        implicitHeight: col.implicitHeight + padding * 2

        Column {
            id: col
            width: parent.width
            spacing: 2

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                GlyphText {
                    text: root.modelData.summary
                    role: "body"
                    width: parent.width - time.width - parent.spacing
                    font.weight: Font.Medium
                    wrapMode: root.expanded ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: root.expanded ? 4 : 1
                }

                GlyphText {
                    id: time
                    text: root.modelData.timeStr
                    role: "label"
                    dim: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            GlyphText {
                visible: root.modelData.body !== ""
                text: root.modelData.body
                role: "small"
                dim: true
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: root.expanded ? 30 : 2
                textFormat: Text.StyledText
                linkColor: Theme.spark
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                width: parent.width
                spacing: Theme.spaceXs
                visible: root.expanded && root.modelData.actions.length > 0
                topPadding: Theme.spaceXs

                Repeater {
                    model: root.modelData.actions

                    HexButton {
                        required property var modelData
                        text: modelData.text
                        padding: Theme.spaceXs
                        maxWidth: 120
                        onClicked: {
                            modelData.invoke();
                            root.modelData.close();
                        }
                    }
                }
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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true
        drag.target: root
        drag.axis: Drag.XAxis
        drag.threshold: 10

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
            if (Math.abs(root.x) >= root.width * 0.33) {
                root.x = root.x > 0 ? root.width * 1.2 : -root.width * 1.2;
                root.modelData.close();
            } else {
                root.x = 0;
            }
        }
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                root.expanded = !root.expanded;
                return;
            }
            if (event.button !== Qt.LeftButton || vertical || Math.abs(root.x) > 4)
                return;
            Notifs.activate(root.modelData);
        }
    }
}
