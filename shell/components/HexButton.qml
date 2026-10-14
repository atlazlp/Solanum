import QtQuick
import qs.theme

// Clickable chamfered/hex surface. Hover = line 100% + ink2; press = lineSoft 14% for 90 ms.
// States: active (filled line tint), danger (danger colour), disabled.
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string shape: "chamfer"
    property int chamfer: Theme.chamferSm
    property bool active: false
    property bool danger: false
    property bool flat: false          // no fill/line until hovered
    property bool glow: false
    property int padding: Theme.spaceSm
    property real iconSize: Theme.sizeIcon
    property real iconFill: active ? 1 : 0
    property string tooltip: ""
    property int maxWidth: 0            // > 0: elide the label so the button never exceeds this width
    property alias hovered: hover.hovered
    property alias pressed: tap.pressed
    readonly property bool keyFocus: activeFocus
    property color accent: danger ? Theme.danger : Theme.line

    signal clicked()
    signal rightClicked()
    signal wheel(var event)

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    activeFocusOnTab: true
    enabled: true
    opacity: enabled ? 1 : 0.45

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    NomaiFrame {
        id: frame

        anchors.fill: parent
        shape: root.shape
        chamfer: root.chamfer
        padding: root.padding
        glow: root.glow || root.keyFocus
        lineColor: root.accent
        lineOpacity: root.flat && !hover.hovered && !root.active && !root.keyFocus ? 0 : (hover.hovered || root.active || root.keyFocus ? 1 : 0.55)
        fill: {
            if (pressFlash.running)
                return Theme.alpha(Theme.lineSoft, 0.14);
            if (root.active)
                return Theme.alpha(root.accent, 0.16);
            if (hover.hovered)
                return Theme.ink2;
            return root.flat ? "transparent" : Theme.ink1;
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.spaceSm

            GlyphIcon {
                id: iconItem
                visible: root.icon !== ""
                icon: root.icon
                size: root.iconSize
                fill: root.iconFill
                color: root.danger ? Theme.danger : (root.active ? Theme.line : Theme.text)
                animate: true
                anchors.verticalCenter: parent.verticalCenter
            }

            GlyphText {
                visible: root.text !== ""
                text: root.text
                role: "body"
                width: root.maxWidth > 0 ? Math.max(0, Math.min(implicitWidth, root.maxWidth - root.padding * 2 - (root.icon !== "" ? iconItem.implicitWidth + row.spacing : 0))) : implicitWidth
                color: root.danger ? Theme.danger : (root.active ? Theme.line : Theme.text)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (point, button) => {
            pressFlash.restart();
            if (button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }

    WheelHandler {
        onWheel: event => root.wheel(event)
    }

    Timer {
        id: pressFlash
        interval: Motion.press
    }

    NomaiTooltip {
        text: root.tooltip
        show: root.tooltip !== "" && hover.hovered
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: Theme.spaceXs
    }
}
