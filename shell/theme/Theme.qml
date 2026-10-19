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

    // In-memory picks (updated while dragging a colour well). Saved overrides live in
    // Config.appearance.colourOverrides and survive qm-apply rewriting scheme.json.
    property var liveOverrides: ({})

    function hexOf(v): string {
        if (v === undefined || v === null)
            return "";
        const s = String(v).trim();
        if (s === "" || s === "undefined")
            return "";
        return s.startsWith("#") ? s : "#" + s;
    }

    function overrideOf(name: string): string {
        const live = hexOf(liveOverrides[name]);
        if (live !== "")
            return live;
        const saved = Config.appearance ? Config.appearance.colourOverrides : null;
        if (saved && saved[name] !== undefined && saved[name] !== null && String(saved[name]) !== "")
            return hexOf(saved[name]);
        return "";
    }

    function themed(name: string, schemeKey: string, fallback: string): color {
        const o = overrideOf(name);
        return o !== "" ? o : col(schemeKey, fallback);
    }

    // ---- Roles (see docs/dev/design-shell.md) ----
    readonly property color ink0: themed("ink0", "surfaceContainerLowest", "#0b0b10")
    readonly property color ink: themed("ink", "surface", "#121218")
    readonly property color ink1: themed("ink1", "surfaceContainer", "#1a1a22")
    readonly property color ink2: themed("ink2", "surfaceContainerHigh", "#22222c")
    readonly property color ink3: themed("ink3", "surfaceContainerHighest", "#2b2b36")
    readonly property color scrim: alpha(col("scrim", "#000000"), 0.55)
    readonly property color line: themed("line", "primary", "#e0c070")
    readonly property color lineSoft: themed("lineSoft", "primaryContainer", "#6b5a2a")
    readonly property color lineDim: themed("lineDim", "outlineVariant", "#44443f")
    readonly property color glow: alpha(line, 0.18)
    readonly property color text: themed("text", "onSurface", "#e8e6df")
    readonly property color textDim: themed("textDim", "onSurfaceVariant", "#a8a69c")
    readonly property color textOnLine: themed("textOnLine", "onPrimary", "#1a1300")
    // Nomai orange. Fixed unless the user sets an appearance override (palettes map "peach" freely).
    readonly property color ember: overrideOf("ember") !== "" ? overrideOf("ember") : "#e9a23b"
    // Scout / QM moon chrome. Fixed cool grey unless the user sets an override.
    readonly property color moon: overrideOf("moon") !== "" ? overrideOf("moon") : "#c8c4bc"
    // Secondary / tertiary from the planet palette — use alongside `line` so schemes don't read as one hue.
    readonly property color secondary: themed("secondary", "secondary", "#73f8b7")
    readonly property color secondarySoft: col("secondaryContainer", "#006c46")
    readonly property color onSecondary: col("onSecondary", "#005c3b")
    readonly property color spark: themed("spark", "tertiary", "#7fc8ff")
    readonly property color sparkSoft: col("tertiaryContainer", "#00dcfd")
    readonly property color onSpark: col("onTertiary", "#005360")
    readonly property color glowSpark: alpha(spark, 0.22)
    // Firefox / Pywalfox accents (may differ from line/spark when the browser needs a different lead colour).
    readonly property color firefoxAccent: overrideOf("firefox") !== "" ? overrideOf("firefox") : (has("firefoxAccent") ? col("firefoxAccent", "#e0c070") : line)
    readonly property color firefoxAccentSecondary: overrideOf("firefox2") !== "" ? overrideOf("firefox2") : (has("firefoxAccentSecondary") ? col("firefoxAccentSecondary", "#7fc8ff") : spark)
    readonly property color firefoxAccentTertiary: overrideOf("firefox3") !== "" ? overrideOf("firefox3") : (has("firefoxAccentTertiary") ? col("firefoxAccentTertiary", "#3a3a44") : ink2)
    readonly property color danger: themed("danger", "error", "#ff6b6b")
    readonly property color onDanger: col("onError", "#2a0000")
    readonly property color success: themed("success", "success", "#7bd88f")
    readonly property color warn: themed("warn", "yellow", "#f0d060")
    readonly property list<color> term: [col("term0", "#000000"), col("term1", "#cc3333"), col("term2", "#33cc33"), col("term3", "#cccc33"), col("term4", "#3333cc"), col("term5", "#cc33cc"), col("term6", "#33cccc"), col("term7", "#cccccc"), col("term8", "#666666"), col("term9", "#ff5555"), col("term10", "#55ff55"), col("term11", "#ffff55"), col("term12", "#5555ff"), col("term13", "#ff55ff"), col("term14", "#55ffff"), col("term15", "#ffffff")]
    // Accent cycle for visualisers / multi-hue details (primary → secondary → tertiary).
    readonly property list<color> accents: [line, secondary, spark]

    // ---- Fonts ----
    // Titles: ITC Avant Garde · Subtitles/emphasis: ITC Serif Gothic · Body: Space Mono
    readonly property list<string> installedFamilies: Qt.fontFamilies()
    readonly property string fontDisplay: installedFamilies.includes("ITC Avant Garde Std Md")
        ? "ITC Avant Garde Std Md"
        : (installedFamilies.includes("ITC Avant Garde Gothic Std") ? "ITC Avant Garde Gothic Std" : "Rubik")
    readonly property string fontSubtitle: installedFamilies.includes("ITC Serif Gothic") ? "ITC Serif Gothic" : fontDisplay
    readonly property string fontBody: installedFamilies.includes("Space Mono") ? "Space Mono" : "Rubik"
    readonly property string fontMono: installedFamilies.includes("Space Mono") ? "Space Mono" : (installedFamilies.includes("JetBrainsMono NF") ? "JetBrainsMono NF" : "monospace")
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
    readonly property int tickLength: 6
    readonly property real tickWidth: 1.75
    readonly property real letterSpacingHeader: 2
    // Regular flat-top hexagon: width/height = 2/√3 so all six sides are equal.
    readonly property real hexAspect: 2 / Math.sqrt(3)
    function hexWidth(h: real): real { return h * hexAspect; }
    function hexHeight(w: real): real { return w / hexAspect; }

    // Z order
    readonly property int zBar: 10
    readonly property int zPopout: 20
    readonly property int zPanel: 30
    readonly property int zModal: 40
    readonly property int zToast: 50
    readonly property int zLock: 100
    // Above every in-window layer, including menus that escape a Flickable.
    readonly property int zTooltip: 10000

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
