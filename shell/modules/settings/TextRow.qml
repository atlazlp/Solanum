import QtQuick
import qs.components
import qs.theme

// Free text. Writes on every keystroke (debounced by the store); resyncs when unfocused.
SettingRow {
    id: row

    property string placeholder: ""
    property string icon: ""
    property int fieldWidth: 300
    property bool mono: false
    // Optional converters between stored value and text.
    property var toText: v => v === undefined || v === null ? "" : String(v)
    property var fromText: t => t

    function sync(): void {
        if (!field.focused)
            field.text = row.toText(row.current);
    }

    onCurrentChanged: sync()
    Component.onCompleted: sync()

    NomaiTextField {
        id: field
        implicitWidth: row.stacked ? row.width : row.fieldWidth
        width: row.stacked ? row.width : row.fieldWidth
        placeholder: row.placeholder
        icon: row.icon
        input.font.family: row.mono ? Theme.fontMono : Theme.fontBody
        onTextChanged: {
            if (focused && text !== row.toText(row.current))
                row.write(row.fromText(text));
        }
        onEscaped: input.focus = false
        onAccepted: input.focus = false
    }
}
