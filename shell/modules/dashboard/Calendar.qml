pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// Month grid with prev/next navigation; today is marked with a hex pip.
Column {
    id: root

    property int year: Time.date.getFullYear()
    property int month: Time.date.getMonth()      // 0-based
    readonly property int cell: 30
    readonly property var locale: Qt.locale("en_US")
    readonly property int firstDow: locale.firstDayOfWeek % 7   // 0 = Sunday

    readonly property var days: {
        const first = new Date(year, month, 1);
        const lead = (first.getDay() - firstDow + 7) % 7;
        const start = new Date(year, month, 1 - lead);
        const out = [];
        const today = Time.date;
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                today: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate(),
                weekend: d.getDay() === 0 || d.getDay() === 6
            });
        }
        return out;
    }

    readonly property list<string> dowLabels: {
        const out = [];
        for (let i = 0; i < 7; i++)
            out.push(locale.dayName((firstDow + i) % 7 === 0 ? 7 : (firstDow + i) % 7, Locale.ShortFormat).slice(0, 2));
        return out;
    }

    function shift(delta: int): void {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    function reset(): void {
        year = Time.date.getFullYear();
        month = Time.date.getMonth();
    }

    spacing: Theme.spaceSm
    width: cell * 7

    Item {
        width: parent.width
        implicitHeight: Math.max(prev.implicitHeight, title.implicitHeight)

        HexButton {
            id: prev
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron_left"
            flat: true
            padding: Theme.spaceXs
            iconSize: Theme.sizeSmall + 5
            onClicked: root.shift(-1)
        }

        GlyphText {
            id: title
            anchors.centerIn: parent
            role: "label"
            text: locale.monthName(root.month, Locale.LongFormat) + " " + root.year
            color: Theme.text
            TapHandler { onTapped: root.reset() }
        }

        HexButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron_right"
            flat: true
            padding: Theme.spaceXs
            iconSize: Theme.sizeSmall + 5
            onClicked: root.shift(1)
        }
    }

    Grid {
        columns: 7
        rows: 7
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
            model: root.dowLabels

            Item {
                required property string modelData
                width: root.cell
                height: root.cell * 0.7
                GlyphText {
                    anchors.centerIn: parent
                    role: "label"
                    text: parent.modelData
                    dim: true
                    font.letterSpacing: 0
                }
            }
        }

        Repeater {
            model: root.days

            Item {
                id: dayCell

                required property var modelData
                width: root.cell
                height: root.cell

                // Hex marker for today
                NomaiFrame {
                    visible: dayCell.modelData.today
                    anchors.centerIn: parent
                    width: root.cell - 4
                    height: root.cell - 4
                    shape: "hex"
                    fill: Theme.alpha(Theme.line, 0.16)
                    lineColor: Theme.line
                    glow: true
                    padding: 0
                }

                GlyphText {
                    anchors.centerIn: parent
                    role: "small"
                    text: dayCell.modelData.day
                    color: dayCell.modelData.today ? Theme.line : (dayCell.modelData.weekend ? Theme.textDim : Theme.text)
                    opacity: dayCell.modelData.inMonth ? 1 : 0.35
                    font.weight: dayCell.modelData.today ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.shift(event.angleDelta.y < 0 ? 1 : -1)
    }
}
