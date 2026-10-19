pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    id: pane

    readonly property list<string> roleColumns: ["main", "left", "right", "*"]
    readonly property var screenModel: [{ value: "", label: "(none)" }].concat(Screens.names.map(n => ({ value: n, label: n })))

    readonly property var modules: {
        void SettingsStore.generation;
        const m = SettingsStore.get("modules", {});
        return m !== null && typeof m === "object" ? m : {};
    }
    readonly property list<string> moduleKeys: Object.keys(modules)

    function normalized(entry: var): list<string> {
        if (entry === "*" || entry === true)
            return ["*"];
        if (Array.isArray(entry))
            return entry.map(v => String(v));
        return [];
    }

    function isOn(key: string, role: string): bool {
        const l = normalized(modules[key]);
        return l.includes("*") || l.includes(role);
    }

    function isAll(key: string): bool {
        return normalized(modules[key]).includes("*");
    }

    function moduleName(key: string): string {
        const names = {
            "lock.fullUi": "Lock screen",
            "windowPicker": "Window picker",
            "quantumMoon": "Solanum",
            "osd": "OSD",
            "sidebar": "Signals",
            "hover.launcher": "Launcher hover",
            "hover.dashboard": "Dashboard hover",
            "hover.sidebar": "Signals hover",
            "hover.quantumMoon": "Solanum hover",
            "hover.audio": "Volume hover"
        };
        return names[key] || SettingsStore.humanize(key);
    }

    function columnLabel(role: string): string {
        return role === "*" ? "All" : SettingsStore.humanize(role);
    }
    function toggle(key: string, role: string): void {
        const l = normalized(modules[key]);
        let next;
        if (role === "*")
            next = l.includes("*") ? [] : "*";
        else if (l.includes("*"))
            next = ["main", "left", "right"].filter(r => r !== role);
        else
            next = l.includes(role) ? l.filter(r => r !== role) : l.concat([role]);
        const m = Object.assign({}, modules);
        m[key] = next;
        SettingsStore.set("modules", m);
    }

    ComboRow {
        key: "screens.roles.main"
        label: "Main screen"
        description: "Bar, notifications and the Solanum panel follow it. Now: " + Screens.mainName
        model: pane.screenModel
    }

    ComboRow {
        key: "screens.roles.left"
        label: "Left screen"
        model: pane.screenModel
    }

    ComboRow {
        key: "screens.roles.right"
        label: "Right screen"
        model: pane.screenModel
    }

    ComboRow {
        key: "screens.fallbackMain"
        label: "Fallback main"
        description: "Used when the main screen is unplugged"
        model: pane.screenModel
    }

    SectionHeader {
        text: "Fullscreen"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "general.showOverFullscreen"
        label: "Draw over fullscreen"
        description: "Keep the bar and panels visible while a window is fullscreen"
    }

    SectionHeader {
        text: "Where things appear"
        topPadding: Theme.spaceLg
    }

    GlyphText {
        text: "Which screens each part of the shell is drawn on. All means every screen."
        role: "small"
        dim: true
        topPadding: Theme.spaceXs
        bottomPadding: Theme.spaceSm
    }

    // header
    Item {
        id: matrixHead
        property bool filterHidden: false
        width: parent.width
        height: 24

        states: State {
            name: "filtered"
            when: matrixHead.filterHidden
            PropertyChanges {
                matrixHead.visible: false
                matrixHead.height: 0
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: pane.roleColumns

                GlyphText {
                    required property string modelData
                    width: 72
                    text: pane.columnLabel(modelData)
                    role: "label"
                    dim: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Repeater {
        model: pane.moduleKeys

        Item {
            id: matrixRow
            required property string modelData
            readonly property bool all: pane.isAll(modelData)

            width: parent.width
            height: 48
            property bool filterHidden: false

            states: State {
                name: "filtered"
                when: matrixRow.filterHidden
                PropertyChanges {
                    matrixRow.visible: false
                    matrixRow.height: 0
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.alpha(Theme.lineDim, 0.3)
            }

            Column {
                anchors.left: parent.left
                anchors.right: cells.left
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                GlyphText {
                    text: pane.moduleName(matrixRow.modelData)
                    width: parent.width
                    elide: Text.ElideRight
                }

                GlyphText {
                    text: matrixRow.modelData
                    role: "mono"
                    dim: true
                    font.pointSize: Theme.sizeLabel
                    width: parent.width
                    elide: Text.ElideRight
                }
            }

            Row {
                id: cells
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: pane.roleColumns

                    Item {
                        id: cell
                        required property string modelData
                        readonly property bool implied: matrixRow.all && modelData !== "*"

                        width: 72
                        height: 32

                        NomaiFrame {
                            visible: pane.isOn(matrixRow.modelData, cell.modelData)
                            height: Theme.hexPip
                            width: Theme.hexWidth(Theme.hexPip)
                            shape: "hex"
                            padding: 0
                            fill: Theme.line
                            lineColor: Theme.line
                            opacity: cell.implied ? 0.45 : 1
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        NomaiSwitch {
                            id: sw
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: cell.implied ? 0.45 : 1
                            checked: pane.isOn(matrixRow.modelData, cell.modelData)
                            onToggled: {
                                pane.toggle(matrixRow.modelData, cell.modelData);
                                Qt.callLater(() => sw.checked = Qt.binding(() => pane.isOn(matrixRow.modelData, cell.modelData)));
                            }
                        }
                    }
                }
            }
        }
    }
}
