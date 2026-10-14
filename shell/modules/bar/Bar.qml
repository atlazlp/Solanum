pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.theme
import qs.services
import "segments" as Segments

// Row of HexSegments built from Config.bar.entries (ids: logo, workspaces, spacer, activeWindow, tray, clock, status, power).
Item {
    id: root

    required property ShellScreen screen
    // Depend on Visibilities.generation so these re-resolve once the drawers window has registered.
    readonly property DrawerVisibilities visibilities: {
        void Visibilities.generation;
        return Visibilities.forScreen(screen.name);
    }
    readonly property var popouts: {
        void Visibilities.generation;
        return Visibilities.popoutFor(screen.name);
    }
    readonly property int segmentHeight: height - Theme.spaceXs * 2

    readonly property list<var> entries: (Config.bar.entries ?? []).filter(e => e && e.enabled !== false)

    // Thin ink base line under the segments.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.alpha(Theme.lineDim, 0.6)
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.topMargin: Theme.spaceXs
        anchors.bottomMargin: Theme.spaceXs
        spacing: Theme.spaceSm

        Repeater {
            model: root.entries

            Loader {
                id: entry

                required property var modelData
                required property int index
                readonly property string kind: String(modelData.id ?? "")
                readonly property bool isSpacer: kind === "spacer"
                readonly property bool first: index === 0
                readonly property bool last: index === root.entries.length - 1
                readonly property bool nextIsSpacer: index + 1 < root.entries.length && String(root.entries[index + 1].id) === "spacer"
                readonly property bool prevIsSpacer: index > 0 && String(root.entries[index - 1].id) === "spacer"

                Layout.fillWidth: isSpacer
                Layout.fillHeight: true
                Layout.preferredWidth: isSpacer ? 0 : (item?.implicitWidth ?? 0)
                Layout.minimumWidth: isSpacer ? 0 : (item?.implicitWidth ?? 0)
                Layout.leftMargin: first ? 0 : 0

                sourceComponent: {
                    switch (kind) {
                    case "logo": return logoComp;
                    case "workspaces": return workspacesComp;
                    case "activeWindow": return activeWindowComp;
                    case "tray": return trayComp;
                    case "clock": return clockComp;
                    case "status":
                    case "statusIcons": return statusComp;
                    case "power": return powerComp;
                    case "spacer": return spacerComp;
                    }
                    console.warn(`Bar: unknown entry id "${kind}"`);
                    return spacerComp;
                }

                onLoaded: {
                    if (!item)
                        return;
                    item.screen = root.screen;
                    item.bar = root;
                    if ("ends" in item)
                        item.ends = first ? "right" : (last ? "left" : "both");
                    if ("connector" in item)
                        item.connector = !last && !nextIsSpacer;
                }
            }
        }
    }

    Component { id: logoComp; Segments.Logo {} }
    Component { id: workspacesComp; Segments.Workspaces {} }
    Component { id: activeWindowComp; Segments.ActiveWindow {} }
    Component { id: trayComp; Segments.Tray {} }
    Component { id: clockComp; Segments.Clock {} }
    Component { id: statusComp; Segments.Status {} }
    Component { id: powerComp; Segments.Power {} }
    Component { id: spacerComp; Segments.Spacer {} }
}
