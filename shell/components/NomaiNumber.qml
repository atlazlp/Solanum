import QtQuick
import qs.theme

// Numeric editor: [-] field [+]. Emits edited(value); the caller writes it back into `value`.
// Wheel over the field steps; Return/focus-out commits typed input, clamped to [from, to].
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: -1       // -1: derive from step
    property string suffix: ""
    property int fieldWidth: 84
    readonly property int places: decimals >= 0 ? decimals : (step >= 1 ? 0 : Math.min(4, Math.ceil(-Math.log10(step))))

    signal edited(real value)

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    function fmt(v: real): string {
        return Number(v).toFixed(places);
    }

    function clamp(v: real): real {
        const r = Math.round(v / step) * step;
        return Math.max(from, Math.min(to, Number(r.toFixed(Math.max(places, 4)))));
    }

    function commit(v: real): void {
        if (isNaN(v))
            return;
        const c = clamp(v);
        if (c !== value)
            root.edited(c);
        else
            field.text = fmt(c);
    }

    function nudge(dir: int): void {
        commit(value + dir * step);
    }

    onValueChanged: {
        if (!field.focused)
            field.text = fmt(value);
    }

    Component.onCompleted: field.text = fmt(value)

    Row {
        id: row
        spacing: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter

        HexButton {
            icon: "remove"
            padding: Theme.spaceXs
            iconSize: Theme.sizeBody
            enabled: root.value > root.from
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.nudge(-1)
        }

        NomaiTextField {
            id: field
            implicitWidth: root.fieldWidth
            anchors.verticalCenter: parent.verticalCenter
            input.horizontalAlignment: TextInput.AlignHCenter
            input.validator: DoubleValidator {
                bottom: root.from
                top: root.to
                decimals: root.places
                notation: DoubleValidator.StandardNotation
            }
            onAccepted: root.commit(parseFloat(text))
            onEscaped: {
                text = root.fmt(root.value);
                input.focus = false;
            }
            input.onEditingFinished: root.commit(parseFloat(field.text))
            onFocusedChanged: if (!focused) text = root.fmt(root.value)

            WheelHandler {
                onWheel: event => root.nudge(event.angleDelta.y > 0 ? 1 : -1)
            }
        }

        GlyphText {
            visible: root.suffix !== ""
            text: root.suffix
            role: "small"
            dim: true
            anchors.verticalCenter: parent.verticalCenter
        }

        HexButton {
            icon: "add"
            padding: Theme.spaceXs
            iconSize: Theme.sizeBody
            enabled: root.value < root.to
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.nudge(1)
        }
    }
}
