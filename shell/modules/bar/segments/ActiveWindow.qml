import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services

// App icon + elided title of the focused window. Click toggles the activewindow popout.
HexSegment {
    id: root

    property var screen: null
    property var bar: null

    readonly property var toplevel: Hypr.activeToplevel
    readonly property string appClass: String(toplevel?.lastIpcObject?.class ?? "")
    readonly property string title: toplevel?.title || "Desktop"
    readonly property int maxWidth: Config.bar.activeWindow.maxWidth ?? 420

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
            host.show("activewindow", root.mapToItem(null, 0, 0).x, root.width, null, true);
    }

    Row {
        spacing: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        AppIcon {
            appId: root.appClass
            fallbackIcon: "desktop_windows"
            size: Theme.sizeIcon * 1.1
            anchors.verticalCenter: parent.verticalCenter
        }

        GlyphText {
            text: root.title
            role: "body"
            width: Math.min(implicitWidth, root.maxWidth)
            anchors.verticalCenter: parent.verticalCenter

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: parent; property: "opacity"; to: 0; duration: Motion.fast }
                    PropertyAction {}
                    NumberAnimation { target: parent; property: "opacity"; to: 1; duration: Motion.fast }
                }
            }
        }
    }
}
