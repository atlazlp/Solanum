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

    // Keys like "hover.launcher" contain dots, so the whole matrix is written as one object.
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
        description: "Bar, notifications and the QM panel follow it. Now: " + Screens.mainName
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
        text: "Module matrix"
        topPadding: Theme.spaceLg
    }

    GlyphText {
        text: "Which screen roles each module appears on. * = every screen."
        role: "small"
        dim: true
        topPadding: Theme.spaceXs
        bottomPadding: Theme.spaceSm
    }

    // header
    Item {
        width: parent.width
        height: 24

        Row {
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: pane.roleColumns

                GlyphText {
                    required property string modelData
                    width: 72
                    text: modelData
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
            height: 32

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.alpha(Theme.lineDim, 0.3)
            }

            GlyphText {
                text: matrixRow.modelData
                role: "mono"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
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
                        height: 24

                        NomaiSwitch {
                            id: sw
                            anchors.centerIn: parent
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
