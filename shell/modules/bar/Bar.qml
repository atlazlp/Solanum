pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.theme
import qs.services
import "segments" as Segments

// Column of HexSegments from Config.bar.entries. Spacers use fillHeight (justify-between).
Item {
    id: root

    required property ShellScreen screen
    readonly property DrawerVisibilities visibilities: {
        void Visibilities.generation;
        return Visibilities.forScreen(screen.name);
    }
    readonly property var popouts: {
        void Visibilities.generation;
        return Visibilities.popoutFor(screen.name);
    }

    readonly property list<var> entries: (Config.bar.entries ?? []).filter(e => e && e.enabled !== false)

    ColumnLayout {
        id: col

        anchors.fill: parent
        spacing: Theme.spaceXs

        Repeater {
            model: root.entries

            Loader {
                id: entry

                required property var modelData
                required property int index
                readonly property string kind: String(modelData.id ?? "")
                readonly property bool isSpacer: kind === "spacer"
                readonly property bool isActiveWindow: kind === "activeWindow"
                readonly property bool first: index === 0
                readonly property bool last: index === root.entries.length - 1
                readonly property bool nextIsSpacer: index + 1 < root.entries.length && String(root.entries[index + 1].id) === "spacer"

                Layout.fillWidth: true
                // Active window absorbs free height (shrinks when tray/status grow); spacers stay as gaps only.
                Layout.fillHeight: isActiveWindow
                Layout.preferredHeight: isSpacer ? 0 : (item?.implicitHeight ?? 0)
                Layout.minimumHeight: isSpacer ? 0 : (item?.implicitHeight ?? 0)

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
                    if ("vertical" in item)
                        item.vertical = true;
                    if ("ends" in item)
                        item.ends = first ? "bottom" : (last ? "top" : "both");
                    if ("connector" in item)
                        item.connector = !last && !nextIsSpacer;
                    if (isActiveWindow) {
                        item.anchors.fill = entry;
                    }
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
