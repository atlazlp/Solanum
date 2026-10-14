pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    id: pane

    readonly property list<var> roles: [
        { name: "ink0", c: Theme.ink0 }, { name: "ink", c: Theme.ink }, { name: "ink1", c: Theme.ink1 },
        { name: "ink2", c: Theme.ink2 }, { name: "ink3", c: Theme.ink3 }, { name: "line", c: Theme.line },
        { name: "lineSoft", c: Theme.lineSoft }, { name: "lineDim", c: Theme.lineDim }, { name: "text", c: Theme.text },
        { name: "textDim", c: Theme.textDim }, { name: "textOnLine", c: Theme.textOnLine }, { name: "ember", c: Theme.ember },
        { name: "spark", c: Theme.spark }, { name: "danger", c: Theme.danger }, { name: "success", c: Theme.success },
        { name: "warn", c: Theme.warn }
    ]

    NumberRow {
        key: "appearance.fontScale"
        label: "Font scale"
        description: "Multiplier for every font size"
        from: 0.5
        to: 2
        step: 0.05
        fallback: 1
    }

    NumberRow {
        key: "appearance.motionScale"
        label: "Motion scale"
        description: "Multiplier for animation durations (0 disables motion)"
        from: 0
        to: 3
        step: 0.1
        fallback: 1
    }

    NumberRow {
        key: "appearance.padding"
        label: "Padding scale"
        description: "Multiplier for spacing tokens"
        from: 0.5
        to: 2
        step: 0.05
        fallback: 1
    }

    SectionHeader {
        text: "Palette"
        topPadding: Theme.spaceLg
        bottomPadding: Theme.spaceSm
    }

    GlyphText {
        text: (Theme.schemeName ? Theme.schemeName + (Theme.flavour ? " / " + Theme.flavour : "") : "fallback scheme") + " (" + Theme.mode + ")"
        role: "small"
        dim: true
        bottomPadding: Theme.spaceSm
    }

    Flow {
        width: parent.width
        spacing: Theme.spaceSm

        Repeater {
            model: pane.roles

            Column {
                id: swatch
                required property var modelData
                spacing: 2

                NomaiFrame {
                    width: 92
                    height: 40
                    padding: 0
                    chamfer: Theme.chamferSm
                    fill: swatch.modelData.c
                    lineColor: Theme.lineDim
                    lineOpacity: 0.8
                }

                GlyphText {
                    text: swatch.modelData.name
                    role: "small"
                }

                GlyphText {
                    text: String(swatch.modelData.c)
                    role: "mono"
                    dim: true
                    font.pointSize: Theme.sizeLabel
                }
            }
        }
    }

    SectionHeader {
        text: "Fonts"
        topPadding: Theme.spaceLg
        bottomPadding: Theme.spaceSm
    }

    Column {
        spacing: 2

        GlyphText { text: "Display: " + Theme.fontDisplay; role: "title" }
        GlyphText { text: "Body: " + Theme.fontBody; role: "body" }
        GlyphText { text: "Mono: " + Theme.fontMono; role: "mono" }
    }
}
