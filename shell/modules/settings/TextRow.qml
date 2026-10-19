import QtQuick
import qs.components
import qs.theme

// Free text. Commits on Return or leaving the field. `validate` returns an error string, or "" when
// the text can be saved.
SettingRow {
    id: row

    property string placeholder: ""
    property string icon: ""
    property int fieldWidth: 300
    property bool mono: false
    property string error: ""
    // Optional converters between stored value and text.
    property var toText: v => v === undefined || v === null ? "" : String(v)
    property var fromText: t => t
    property var validate: null

    function sync(): void {
        if (!field.focused)
            field.text = row.toText(row.current);
    }

    function same(a, b): bool {
        if (a === b)
            return true;
        if (typeof a === "number" && typeof b === "number")
            return Math.abs(a - b) < 1e-6;
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function commit(): void {
        const err = row.validate ? String(row.validate(field.text) || "") : "";
        row.error = err;
        if (err !== "")
            return;
        const next = row.fromText(field.text);
        if ((row.current === undefined || row.current === null) && next === "")
            return;
        if (!same(next, row.current))
            row.write(next);
    }

    onCurrentChanged: sync()
    Component.onCompleted: sync()

    Column {
        spacing: 2

        NomaiTextField {
            id: field
            implicitWidth: row.stacked ? row.width : row.fieldWidth
            width: row.stacked ? row.width : row.fieldWidth
            placeholder: row.placeholder
            icon: row.icon
            input.font.family: row.mono ? Theme.fontMono : Theme.fontBody
            onEscaped: {
                row.error = "";
                row.sync();
                input.focus = false;
            }
            onAccepted: {
                row.commit();
                if (row.error === "")
                    input.focus = false;
            }
            input.onEditingFinished: row.commit()
        }

        GlyphText {
            visible: row.error !== ""
            text: row.error
            role: "small"
            width: field.width
            wrapMode: Text.WordWrap
            color: Theme.danger
        }
    }
}
