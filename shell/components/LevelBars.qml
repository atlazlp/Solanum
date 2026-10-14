import QtQuick
import qs.theme

// N thin bars lit up to `level` (0..1). Used for audio peak meters.
Row {
    id: root

    property real level: 0
    property int bars: 8
    property int barWidth: 3
    property int barHeight: 14
    property color accent: Theme.line
    property bool vertical: false

    spacing: 2

    Repeater {
        model: root.bars

        Rectangle {
            required property int index
            readonly property bool lit: root.level * root.bars > index
            width: root.barWidth
            height: root.barHeight
            y: (root.height - height) / 2
            color: lit ? (index >= root.bars - 2 ? Theme.ember : root.accent) : Theme.alpha(Theme.lineDim, 0.5)

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }
    }
}
