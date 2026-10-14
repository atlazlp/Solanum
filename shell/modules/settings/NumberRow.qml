import QtQuick
import qs.components

SettingRow {
    id: row

    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: -1
    property string suffix: ""
    property real fallback: 0

    NomaiNumber {
        value: typeof row.current === "number" ? row.current : row.fallback
        from: row.from
        to: row.to
        step: row.step
        decimals: row.decimals
        suffix: row.suffix
        onEdited: v => row.write(v)
    }
}
