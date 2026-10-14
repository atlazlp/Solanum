pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Colour roles, fonts, sizes and spacing. Colours come from `state/scheme.json` (.colours, hex without '#')
// written by qm-apply; every role has a safe fallback so the shell renders before the file exists.
Singleton {
    id: root

    property var colours: ({})
    property string schemeName: ""
    property string flavour: ""
    property string mode: "dark"
    readonly property bool light: mode === "light"

    function has(name: string): bool {
        return colours[name] !== undefined;
    }

    function col(name: string, fallback: string): color {
        const v = colours[name];
        if (v === undefined || v === null)
            return fallback;
        const s = String(v);
        return s.startsWith("#") ? s : "#" + s;
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // ---- Roles (see docs/dev/design-shell.md) ----
    readonly property color ink0: col("surfaceContainerLowest", "#0b0b10")
    readonly property color ink: col("surface", "#121218")
    readonly property color ink1: col("surfaceContainer", "#1a1a22")
    readonly property color ink2: col("surfaceContainerHigh", "#22222c")
    readonly property color ink3: col("surfaceContainerHighest", "#2b2b36")
    readonly property color scrim: alpha(col("scrim", "#000000"), 0.55)
    readonly property color line: col("primary", "#e0c070")
    readonly property color lineSoft: col("primaryContainer", "#6b5a2a")
    readonly property color lineDim: col("outlineVariant", "#44443f")
    readonly property color glow: alpha(line, 0.18)
    readonly property color text: col("onSurface", "#e8e6df")
    readonly property color textDim: col("onSurfaceVariant", "#a8a69c")
    readonly property color textOnLine: col("onPrimary", "#1a1300")
    readonly property color ember: "#e9a23b"  // Nomai orange, fixed: palettes map "peach" to arbitrary hues
    readonly property color spark: col("tertiary", "#7fc8ff")
    readonly property color danger: col("error", "#ff6b6b")
    readonly property color onDanger: col("onError", "#2a0000")
    readonly property color success: col("success", "#7bd88f")
    readonly property color warn: col("yellow", "#f0d060")
    readonly property list<color> term: [col("term0", "#000000"), col("term1", "#cc3333"), col("term2", "#33cc33"), col("term3", "#cccc33"), col("term4", "#3333cc"), col("term5", "#cc33cc"), col("term6", "#33cccc"), col("term7", "#cccccc"), col("term8", "#666666"), col("term9", "#ff5555"), col("term10", "#55ff55"), col("term11", "#ffff55"), col("term12", "#5555ff"), col("term13", "#ff55ff"), col("term14", "#55ffff"), col("term15", "#ffffff")]

    // ---- Fonts ----
    readonly property list<string> installedFamilies: Qt.fontFamilies()
    readonly property string fontDisplay: installedFamilies.includes("Orbitron") ? "Orbitron" : "Rubik"
    readonly property string fontBody: "Rubik"
    readonly property string fontMono: installedFamilies.includes("JetBrainsMono NF") ? "JetBrainsMono NF" : (installedFamilies.includes("JetBrainsMono Nerd Font") ? "JetBrainsMono Nerd Font" : "monospace")
    readonly property string fontIcon: "Material Symbols Rounded"

    readonly property real fontScale: Config.appearance.fontScale ?? 1
    readonly property real paddingScale: Config.appearance.padding ?? 1

    // Point sizes (x fontScale)
    readonly property real sizeLabel: 10 * fontScale
    readonly property real sizeSmall: 11 * fontScale
    readonly property real sizeBody: 13 * fontScale
    readonly property real sizeLarge: 15 * fontScale
    readonly property real sizeTitle: 18 * fontScale
    readonly property real sizeDisplay: 42 * fontScale
    readonly property real sizeIcon: 18 * fontScale

    // Spacing (px)
    readonly property int spaceXs: Math.round(4 * paddingScale)
    readonly property int spaceSm: Math.round(6 * paddingScale)
    readonly property int spaceMd: Math.round(10 * paddingScale)
    readonly property int spaceLg: Math.round(14 * paddingScale)
    readonly property int spaceXl: Math.round(20 * paddingScale)

    // Chamfers
    readonly property int chamferSm: 6
    readonly property int chamferMd: 10
    readonly property int chamferLg: 14

    readonly property int lineWidth: 1
    readonly property int glowWidth: 6
    readonly property int hexPip: 10
    readonly property int tickLength: 5
    readonly property real letterSpacingHeader: 2

    // Z order
    readonly property int zBar: 10
    readonly property int zPopout: 20
    readonly property int zPanel: 30
    readonly property int zModal: 40
    readonly property int zToast: 50
    readonly property int zLock: 100

    function applyText(t: string): void {
        try {
            const parsed = JSON.parse(t);
            root.colours = parsed.colours ?? {};
            root.schemeName = String(parsed.name ?? "");
            root.flavour = String(parsed.flavour ?? "");
            root.mode = String(parsed.mode ?? "dark");
        } catch (e) {
            console.warn("Theme: invalid scheme.json:", e);
        }
    }

    FileView {
        path: Paths.scheme
        watchChanges: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("Theme: could not load", path, err);
        }
    }
}
