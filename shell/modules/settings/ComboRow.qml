import QtQuick
import qs.components

SettingRow {
    id: row

    property var model: []
    property string placeholder: "select"
    property int comboWidth: 220

    NomaiCombo {
        implicitWidth: row.comboWidth
        model: row.model
        placeholder: row.placeholder
        currentValue: row.current
        onActivated: v => row.write(v)
    }
}
