import QtQuick
import qs.theme
import qs.components

// Continuous value: horizontal slider plus a numeric field. `from` / `to` / `step` are display
// units. Stored value = display / displayScale (100 shows a fraction as a percent).
SettingRow {
    id: row

    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: -1
    property string suffix: ""
    property real fallback: 0
    property real displayScale: 1
    property color accent: Theme.line

    function storedOf(display: real): real {
        const snapped = row.step > 0 ? Math.round(display / row.step) * row.step : display;
        const clamped = Math.max(row.from, Math.min(row.to, snapped));
        return row.displayScale === 1 ? Number(clamped.toFixed(6)) : Number((clamped / row.displayScale).toFixed(6));
    }

    readonly property real shown: ((typeof current === "number" ? current : fallback) * displayScale)

    Row {
        spacing: Theme.spaceSm

        NomaiSlider {
            orientation: Qt.Horizontal
            length: 168
            thickness: 32
            from: row.from
            to: row.to
            step: row.step
            value: row.shown
            accent: row.accent
            showReadout: false
            anchors.verticalCenter: parent.verticalCenter
            onMoved: v => row.write(row.storedOf(v))
        }

        NomaiNumber {
            value: row.shown
            from: row.from
            to: row.to
            step: row.step
            decimals: row.decimals
            suffix: row.suffix
            anchors.verticalCenter: parent.verticalCenter
            onEdited: v => row.write(row.storedOf(v))
        }
    }
}
