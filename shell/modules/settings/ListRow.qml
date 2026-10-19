pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components

// Editor for a list of strings: each item in a chamfered chip with a remove button, plus an
// add field (Return adds). Writes the whole array.
SettingRow {
    id: row

    property string placeholder: "add..."
    property bool mono: false
    property string error: ""
    property var validateItem: null
    readonly property list<string> items: Array.isArray(current) ? current.map(v => String(v)) : []

    stacked: true

    function add(v: string): void {
        const t = v.trim();
        if (t === "")
            return;
        if (row.validateItem) {
            const err = String(row.validateItem(t) || "");
            if (err !== "") {
                row.error = err;
                return;
            }
        }
        row.error = "";
        row.write(items.concat([t]));
    }

    function removeAt(i: int): void {
        const next = items.slice();
        next.splice(i, 1);
        row.write(next);
    }

    Column {
        width: row.width
        spacing: Theme.spaceXs

        Flow {
            width: parent.width
            spacing: Theme.spaceXs

            Repeater {
                model: row.items

                NomaiFrame {
                    id: chip
                    required property string modelData
                    required property int index

                    padding: 0
                    chamfer: Theme.chamferSm
                    fill: Theme.ink0
                    lineOpacity: 0.6
                    implicitHeight: 32
                    implicitWidth: chipRow.implicitWidth + Theme.spaceSm * 2

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Theme.spaceXs

                        GlyphText {
                            text: chip.modelData
                            role: row.mono ? "mono" : "body"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        HexButton {
                            icon: "close"
                            flat: true
                            danger: true
                            padding: 1
                            iconSize: Theme.sizeSmall
                            tooltip: "Remove"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: row.removeAt(chip.index)
                        }
                    }
                }
            }

            GlyphText {
                visible: row.items.length === 0
                text: "empty"
                role: "small"
                dim: true
                height: 32
            }
        }

        Row {
            spacing: Theme.spaceXs

            NomaiTextField {
                id: addField
                implicitWidth: 320
                placeholder: row.placeholder
                icon: "add"
                input.font.family: row.mono ? Theme.fontMono : Theme.fontBody
                onAccepted: {
                    row.add(text);
                    if (row.error === "")
                        text = "";
                }
                onEscaped: input.focus = false
                onTextChanged: {
                    if (row.error !== "")
                        row.error = "";
                }
            }

            HexButton {
                text: "Add"
                icon: "add"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    row.add(addField.text);
                    if (row.error === "")
                        addField.text = "";
                }
            }
        }

        GlyphText {
            visible: row.error !== ""
            text: row.error
            role: "small"
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.danger
        }
    }
}
