import QtQuick
import qs.components

SettingRow {
    id: row

    property bool fallback: false

    NomaiSwitch {
        id: sw
        checked: row.current === undefined ? row.fallback : row.current === true
        onToggled: v => {
            row.write(v);
            // NomaiSwitch assigns `checked` on tap; put the binding back so external changes show.
            Qt.callLater(() => sw.checked = Qt.binding(() => row.current === undefined ? row.fallback : row.current === true));
        }
    }
}
