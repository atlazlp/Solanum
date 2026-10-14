import QtQuick
import qs.theme

// Line chart of `values` (array of numbers), autoscaled unless `max` > 0.
Canvas {
    id: root

    property var values: []
    property real max: 0
    property color accent: Theme.line
    property bool fillArea: true

    implicitWidth: 80
    implicitHeight: 24

    onValuesChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values ?? [];
        if (v.length < 2)
            return;
        let m = max > 0 ? max : Math.max(...v);
        if (m <= 0)
            m = 1;
        const step = width / (v.length - 1);
        ctx.beginPath();
        for (let i = 0; i < v.length; i++) {
            const x = i * step;
            const y = height - (Math.max(0, Math.min(m, v[i])) / m) * (height - 1) - 0.5;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        if (fillArea) {
            ctx.save();
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.14);
            ctx.fill();
            ctx.restore();
            ctx.beginPath();
            for (let i = 0; i < v.length; i++) {
                const x = i * step;
                const y = height - (Math.max(0, Math.min(m, v[i])) / m) * (height - 1) - 0.5;
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
        }
        ctx.lineWidth = 1;
        ctx.strokeStyle = accent;
        ctx.stroke();
    }
}
