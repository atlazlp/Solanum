import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services

// Focused window icon (title in tooltip). Expands to fill free bar height; logo stays centred.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    readonly property var toplevel: Hypr.activeToplevel
    readonly property string appClass: String(toplevel?.lastIpcObject?.class ?? "")
    readonly property string title: toplevel?.title || "Desktop"
    readonly property real iconSize: Theme.sizeIcon * 1.25
    readonly property bool hasWindow: !!toplevel

    padding: Theme.spaceXs
    fill: hasWindow ? Theme.ink2 : Theme.ink1
    ticks: true
    active: (root.bar?.popouts?.currentName ?? "") === "activewindow" && (root.bar?.popouts?.hasCurrent ?? false)
    onExited: {
        if (active)
            root.bar.popouts.scheduleHide();
    }
    onClicked: {
        const host = root.bar?.popouts;
        if (!host)
            return;
        if (host.hasCurrent && host.currentName === "activewindow")
            host.hide();
        else
            host.show("activewindow", root.mapToItem(null, 0, 0).y, root.height, null, true);
    }

    Item {
        // Stretch with the segment so the icon can centre in the expanded area.
        anchors.fill: parent
        implicitWidth: root.iconSize
        implicitHeight: root.iconSize

        AppIcon {
            appId: root.appClass
            fallbackIcon: "desktop_windows"
            size: root.iconSize
            anchors.centerIn: parent
        }
    }

    NomaiTooltip {
        text: root.title
        show: root.hovered && !root.active
        place: "right"
        gap: Theme.spaceSm
    }
}
