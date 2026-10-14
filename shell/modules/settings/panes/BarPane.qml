pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    id: pane

    readonly property var entries: {
        void SettingsStore.generation;
        const e = SettingsStore.get("bar.entries", []);
        return Array.isArray(e) ? e : [];
    }

    function writeEntries(next: var): void {
        SettingsStore.set("bar.entries", next.map(e => ({ id: String(e.id), enabled: e.enabled !== false })));
    }

    function moveEntry(i: int, d: int): void {
        const j = i + d;
        if (j < 0 || j >= entries.length)
            return;
        const next = entries.slice();
        const t = next[i];
        next[i] = next[j];
        next[j] = t;
        writeEntries(next);
    }

    function toggleEntry(i: int, on: bool): void {
        const next = entries.slice();
        next[i] = { id: next[i].id, enabled: on };
        writeEntries(next);
    }

    NumberRow {
        key: "bar.height"
        label: "Bar height"
        description: "Pixels; also the exclusive zone on the main screen"
        from: 24
        to: 64
        step: 1
        suffix: "px"
        fallback: 36
    }

    SettingRow {
        key: "bar.entries"
        label: "Segments"
        description: "Order of the bar row, left to right. Toggle to hide a segment."
        stacked: true

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: pane.entries

                Item {
                    id: entry
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 32

                    NomaiFrame {
                        anchors.fill: parent
                        padding: 0
                        chamfer: Theme.chamferSm
                        fill: Theme.ink0
                        lineOpacity: 0.35
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spaceSm

                        GlyphText {
                            text: String(entry.index + 1).padStart(2, "0")
                            role: "mono"
                            dim: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        GlyphText {
                            text: entry.modelData.id
                            role: "mono"
                            color: entry.modelData.enabled !== false ? Theme.text : Theme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spaceXs

                        NomaiSwitch {
                            checked: entry.modelData.enabled !== false
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: v => pane.toggleEntry(entry.index, v)
                        }

                        HexButton {
                            icon: "arrow_upward"
                            flat: true
                            padding: Theme.spaceXs
                            enabled: entry.index > 0
                            tooltip: "Move up"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: pane.moveEntry(entry.index, -1)
                        }

                        HexButton {
                            icon: "arrow_downward"
                            flat: true
                            padding: Theme.spaceXs
                            enabled: entry.index < pane.entries.length - 1
                            tooltip: "Move down"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: pane.moveEntry(entry.index, 1)
                        }
                    }
                }
            }
        }
    }

    SectionHeader {
        text: "Status glyphs"
        topPadding: Theme.spaceLg
    }

    Repeater {
        model: Object.keys(Config.bar.status ?? {})

        SwitchRow {
            required property string modelData
            key: "bar.status." + modelData
            label: SettingsStore.humanize(modelData)
        }
    }

    SectionHeader {
        text: "Popouts"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "bar.popouts.statusIcons"
        label: "Status popouts"
        description: "Hovering a status glyph opens its popout"
    }

    SwitchRow {
        key: "bar.popouts.tray"
        label: "Tray popouts"
        description: "Hovering a tray icon opens its menu popout"
    }

    SectionHeader {
        text: "Tray"
        topPadding: Theme.spaceLg
    }

    ListRow {
        key: "bar.tray.hiddenIcons"
        label: "Hidden tray icons"
        description: "Tray item ids never shown in the bar"
        placeholder: "item id..."
        mono: true
    }

    SectionHeader {
        text: "Workspaces"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "bar.workspaces.perMonitorWorkspaces"
        label: "Per-monitor workspaces"
        description: "Only show the workspaces of the bar's monitor"
    }

    NumberRow {
        key: "bar.workspaces.shown"
        label: "Workspaces shown"
        description: "Number of workspace pips"
        from: 1
        to: 20
        fallback: 5
    }

    SwitchRow {
        key: "bar.workspaces.showWindows"
        label: "Show windows"
        description: "Draw window icons inside each workspace pip"
    }

    SectionHeader {
        text: "Active window"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "bar.activeWindow.showOnHover"
        label: "Popout on hover"
        description: "Show the active window popout when hovering the title"
    }

    NumberRow {
        key: "bar.activeWindow.maxWidth"
        label: "Title max width"
        from: 120
        to: 1200
        step: 10
        suffix: "px"
        fallback: 420
    }
}
