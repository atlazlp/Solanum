import QtQuick
import qs.theme
import qs.components
import qs.services

// Calculator result card: expression (mono, dim) above the qalc result (large mono).
NomaiFrame {
    id: root

    property string expression: ""

    signal copyRequested()

    padding: Theme.spaceLg
    chamfer: Theme.chamferMd
    fill: Theme.ink0
    glow: Calc.hasResult
    ticks: true
    lineOpacity: Calc.error ? 0.6 : 1
    lineColor: Calc.error ? Theme.danger : Theme.line
    implicitHeight: col.implicitHeight + padding * 2

    TapHandler {
        onTapped: root.copyRequested()
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spaceSm

        Row {
            spacing: Theme.spaceSm
            GlyphIcon {
                icon: "calculate"
                color: Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            GlyphText {
                text: root.expression !== "" ? root.expression : "Type an expression"
                role: "mono"
                dim: true
                anchors.verticalCenter: parent.verticalCenter
                width: root.width - root.padding * 2 - Theme.sizeIcon * 1.6
                elide: Text.ElideLeft
            }
        }

        NomaiDivider {
            width: parent.width
            segments: 5
            color: Theme.lineDim
        }

        GlyphText {
            width: parent.width
            text: {
                if (root.expression === "")
                    return "—";
                if (Calc.busy && Calc.result === "")
                    return "…";
                return Calc.result || "…";
            }
            role: "title"
            font.family: Theme.fontMono
            color: Calc.error ? Theme.danger : Theme.text
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        GlyphText {
            text: Calc.hasResult ? "Enter copies the result" : (Calc.error ? "qalc could not evaluate this" : "")
            role: "label"
            dim: true
            visible: text !== ""
        }
    }
}
