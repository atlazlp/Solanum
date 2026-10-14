import QtQuick
import qs.theme

// A node on the ship-log map: hex frame with an app icon (or a glyph), label below, count pip.
// kind: "hub" | "group" | "entry". Unread nodes pulse their line (0.6 <-> 1, 1.4 s); rumors show "?".
// Position with `cx`/`cy` (centre) so layouts never care about the node size.
Item {
    id: root

    property string kind: "group"
    property string label: ""
    property string iconSource: ""      // image path/url; empty = use `glyph`
    property string glyph: "notifications"
    property int count: 0
    property bool unread: false
    property bool rumor: false
    property bool selected: false
    property bool focused: false
    property bool dimmed: false
    property bool pinned: false
    property bool critical: false
    property real cx: 0
    property real cy: 0
    property real size: kind === "entry" ? 40 : (kind === "hub" ? 64 : 56)
    property int labelWidth: 120

    signal clicked()

    readonly property color accent: critical ? Theme.ember : (rumor ? Theme.lineDim : Theme.line)

    width: size
    height: size
    x: cx - size / 2
    y: cy - size / 2
    opacity: dimmed ? 0.25 : 1
    z: selected || focused ? 2 : 1

    Behavior on opacity {
        NumberAnimation { duration: Motion.normal; easing.type: Motion.fade }
    }
    Behavior on x {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.slide }
    }
    Behavior on y {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.slide }
    }

    NomaiFrame {
        id: hex

        anchors.fill: parent
        shape: "hex"
        padding: 0
        fill: root.selected ? Theme.alpha(root.accent, 0.18) : (hover.hovered ? Theme.ink2 : Theme.ink1)
        lineColor: root.accent
        lineWidth: root.selected || root.focused ? 1.5 : 1
        readonly property bool pulsing: root.unread && !root.selected && !root.focused && !hover.hovered
        property real pulse: 1
        lineOpacity: (root.selected || root.focused || hover.hovered ? 1 : (root.rumor ? 0.6 : 0.85)) * (pulsing ? pulse : 1)
        glow: root.selected || root.focused || hover.hovered || root.kind === "hub"
        glowOpacity: root.selected ? 0.35 : 0.18

        SequentialAnimation on pulse {
            running: hex.pulsing
            loops: Animation.Infinite
            NumberAnimation { to: 0.6; duration: 700; easing.type: Motion.fade }
            NumberAnimation { to: 1; duration: 700; easing.type: Motion.fade }
        }

        Image {
            id: iconImage
            anchors.centerIn: parent
            visible: !root.rumor && root.iconSource !== "" && status === Image.Ready
            source: root.iconSource
            width: root.size * 0.5
            height: root.size * 0.5
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        GlyphIcon {
            anchors.centerIn: parent
            visible: !root.rumor && !iconImage.visible
            icon: root.glyph
            color: root.selected ? root.accent : Theme.text
            fill: root.selected ? 1 : 0
            size: root.size * 0.42
        }

        GlyphText {
            anchors.centerIn: parent
            visible: root.rumor
            text: "?"
            role: "title"
            color: Theme.lineDim
        }
    }

    // Count pip (groups) / pin marker (entries).
    NomaiFrame {
        visible: (root.kind === "group" && root.count > 1) || root.pinned
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        shape: "hex"
        padding: 0
        width: root.pinned && root.kind === "entry" ? 16 : 22
        height: 18
        fill: Theme.ink0
        lineColor: root.accent
        lineOpacity: 0.9

        GlyphText {
            anchors.centerIn: parent
            visible: root.kind === "group"
            text: root.count > 99 ? "99+" : root.count
            role: "label"
            font.letterSpacing: 0
        }

        GlyphIcon {
            anchors.centerIn: parent
            visible: root.kind !== "group"
            icon: "push_pin"
            fill: 1
            size: 11
            color: root.accent
        }
    }

    GlyphText {
        anchors.top: parent.bottom
        anchors.topMargin: Theme.spaceXs
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.labelWidth
        horizontalAlignment: Text.AlignHCenter
        text: root.rumor ? "You've heard a rumor..." : root.label
        role: root.kind === "entry" ? "small" : "label"
        dim: !root.selected
        font.italic: root.rumor
        visible: text !== ""
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
