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
    // Display = stored * displayScale. Timeouts use 0.001 so the field shows seconds.
    property real displayScale: 1

    function storedOf(display: real): real {
        const snapped = row.step > 0 ? Math.round(display / row.step) * row.step : display;
        const clamped = Math.max(row.from, Math.min(row.to, snapped));
        return row.displayScale === 1 ? Number(clamped.toFixed(6)) : Number((clamped / row.displayScale).toFixed(6));
    }

    NomaiNumber {
        readonly property real shown: ((typeof row.current === "number" ? row.current : row.fallback) * row.displayScale)
        value: shown
        from: row.from
        to: row.to
        step: row.step
        decimals: row.decimals
        suffix: row.suffix
        onEdited: v => row.write(row.storedOf(v))
    }
}
