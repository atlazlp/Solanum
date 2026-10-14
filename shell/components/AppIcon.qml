import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.utils

// Desktop icon for an app class/id with a Material glyph fallback.
Item {
    id: root

    property string appId: ""
    property string fallbackIcon: "apps"
    property real size: 20

    readonly property string path: Icons.getAppIcon(appId, "")

    implicitWidth: size
    implicitHeight: size

    IconImage {
        anchors.fill: parent
        visible: root.path !== ""
        source: root.path
        implicitSize: root.size
        asynchronous: true
    }

    GlyphIcon {
        anchors.centerIn: parent
        visible: root.path === ""
        icon: root.fallbackIcon
        size: root.size * 0.75
        color: Theme.textDim
    }
}
