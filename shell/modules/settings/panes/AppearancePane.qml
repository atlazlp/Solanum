pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.modules.settings
import "../../../theme/Colour.js" as Colour

SettingsPane {
    id: pane

    function overrides(): var {
        void SettingsStore.generation;
        const o = SettingsStore.get("appearance.colourOverrides", {});
        return o !== null && typeof o === "object" ? Object.assign({}, o) : {};
    }

    function isOverridden(name: string): bool {
        const o = overrides();
        return o[name] !== undefined && o[name] !== null && String(o[name]) !== "";
    }

    readonly property int overrideCount: Object.keys(overrides()).length

    function writeOverride(name: string, c: color): void {
        const hex = Colour.plainHex(c.r, c.g, c.b);
        const next = overrides();
        if (next[name] === hex)
            return;
        next[name] = hex;
        const live = Object.assign({}, Theme.liveOverrides);
        live[name] = "#" + hex;
        Theme.liveOverrides = live;
        SettingsStore.set("appearance.colourOverrides", next);
    }

    function clearOverride(name: string): void {
        const next = overrides();
        delete next[name];
        const live = Object.assign({}, Theme.liveOverrides);
        delete live[name];
        Theme.liveOverrides = live;
        SettingsStore.set("appearance.colourOverrides", next);
    }

    function clearOverrides(): void {
        Theme.liveOverrides = ({});
        SettingsStore.set("appearance.colourOverrides", ({}));
    }

    readonly property var roleNames: [
        "ink0", "ink", "ink1", "ink2", "ink3", "line", "lineSoft", "lineDim",
        "text", "textDim", "textOnLine", "moon", "ember", "secondary", "spark",
        "firefox", "firefox2", "firefox3", "danger", "success", "warn"
    ]

    function colorFor(name: string): color {
        switch (name) {
        case "ink0": return Theme.ink0;
        case "ink": return Theme.ink;
        case "ink1": return Theme.ink1;
        case "ink2": return Theme.ink2;
        case "ink3": return Theme.ink3;
        case "line": return Theme.line;
        case "lineSoft": return Theme.lineSoft;
        case "lineDim": return Theme.lineDim;
        case "text": return Theme.text;
        case "textDim": return Theme.textDim;
        case "textOnLine": return Theme.textOnLine;
        case "moon": return Theme.moon;
        case "ember": return Theme.ember;
        case "secondary": return Theme.secondary;
        case "spark": return Theme.spark;
        case "firefox": return Theme.firefoxAccent;
        case "firefox2": return Theme.firefoxAccentSecondary;
        case "firefox3": return Theme.firefoxAccentTertiary;
        case "danger": return Theme.danger;
        case "success": return Theme.success;
        case "warn": return Theme.warn;
        default: return Theme.line;
        }
    }

    function fixedRole(name: string): bool {
        return name === "ember" || name === "moon";
    }

    SliderRow {
        key: "appearance.fontScale"
        label: "Font scale"
        description: "Multiplier for every font size"
        from: 0.5
        to: 2
        step: 0.05
        fallback: 1
    }

    SliderRow {
        key: "appearance.motionScale"
        label: "Motion scale"
        description: "Multiplier for animation durations (0 disables motion)"
        from: 0
        to: 3
        step: 0.1
        fallback: 1
    }

    SliderRow {
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
        text: "Ember and moon stay fixed so the Nomai glyphs stay readable. Other colours tint this desktop until you reset them."
        role: "small"
        dim: true
        bottomPadding: Theme.spaceSm
    }

    GlyphText {
        text: (Theme.schemeName ? Theme.schemeName + (Theme.flavour ? " / " + Theme.flavour : "") : "fallback scheme") + " (" + Theme.mode + ")"
        role: "small"
        dim: true
        bottomPadding: Theme.spaceSm
    }

    Flow {
        id: swatches
        property bool filterHidden: false
        width: parent.width
        spacing: Theme.spaceSm

        states: State {
            name: "filtered"
            when: swatches.filterHidden
            PropertyChanges {
                swatches.visible: false
                swatches.height: 0
            }
        }

        Repeater {
            model: pane.roleNames

            NomaiColorWell {
                required property string modelData
                width: 104
                name: modelData
                value: pane.colorFor(modelData)
                fixed: pane.fixedRole(modelData)
                overridden: pane.isOverridden(modelData)
                onPicked: c => pane.writeOverride(modelData, c)
                onCleared: pane.clearOverride(modelData)
            }
        }
    }

    HexButton {
        id: resetPalette
        property bool filterHidden: false
        visible: pane.overrideCount > 0
        text: "Reset palette"
        icon: "restart_alt"
        flat: true
        onClicked: pane.clearOverrides()

        states: State {
            name: "filtered"
            when: resetPalette.filterHidden
        PropertyChanges {
            resetPalette.visible: false
            resetPalette.height: 0
        }
        }
    }

    SectionHeader {
        text: "Fonts"
        topPadding: Theme.spaceLg
        bottomPadding: Theme.spaceSm
    }

    Column {
        id: fonts
        property bool filterHidden: false
        spacing: 2

        states: State {
            name: "filtered"
            when: fonts.filterHidden
        PropertyChanges {
            fonts.visible: false
            fonts.height: 0
        }
        }

        GlyphText {
            text: "Display: " + Theme.fontDisplay
            role: "title"
        }
        GlyphText {
            text: "Body: " + Theme.fontBody
            role: "body"
        }
        GlyphText {
            text: "Mono: " + Theme.fontMono
            role: "mono"
        }
    }
}
